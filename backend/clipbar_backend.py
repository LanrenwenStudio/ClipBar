#!/usr/bin/env python3
"""Small polling cache for ClipBar and CLIProxyAPI.

The service deliberately uses only the Python standard library so it can run on
an always-on router without a package build step.
"""

from __future__ import annotations

import base64
import json
import logging
import os
import signal
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any, Callable


LOG = logging.getLogger("clipbar-backend")
REFRESH_INTERVAL_PRESETS = (60, 180, 300, 600, 900)


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def nearest_refresh_interval(seconds: int) -> int:
    return min(REFRESH_INTERVAL_PRESETS, key=lambda preset: abs(preset - seconds))


def clamp_percent(value: float) -> float:
    return min(max(value, 0.0), 100.0)


def first_value(obj: dict[str, Any], paths: list[str]) -> Any:
    for path in paths:
        current: Any = obj
        for part in path.split("."):
            if not isinstance(current, dict) or part not in current:
                current = None
                break
            current = current[part]
        if current is not None:
            return current
    return None


def first_string(obj: dict[str, Any], paths: list[str]) -> str | None:
    value = first_value(obj, paths)
    if isinstance(value, str):
        value = value.strip()
        return value or None
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return str(value)
    return None


def first_float(obj: dict[str, Any], paths: list[str]) -> float | None:
    value = first_value(obj, paths)
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        try:
            return float(value.strip().rstrip("%"))
        except ValueError:
            return None
    return None


def bool_value(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.strip().lower() in {"1", "true", "yes"}
    return False


def json_object(data: bytes | str) -> dict[str, Any] | None:
    try:
        value = json.loads(data)
    except (TypeError, ValueError):
        return None
    return value if isinstance(value, dict) else None


def parse_iso_date(value: str) -> datetime | None:
    try:
        normalized = value.replace("Z", "+00:00")
        parsed = datetime.fromisoformat(normalized)
        return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)
    except ValueError:
        return None


def format_duration(seconds: float) -> str:
    total = max(0, int(seconds + 0.5))
    hours, remainder = divmod(total, 3600)
    minutes = remainder // 60
    if hours >= 48:
        return f"{hours // 24}d {hours % 24}h"
    if hours > 0:
        return f"{hours}h {minutes}m"
    return f"{minutes}m"


def format_reset(raw: str | None) -> str | None:
    if not raw:
        return None
    parsed = parse_iso_date(raw)
    if parsed is None:
        return raw
    return format_duration((parsed - datetime.now(timezone.utc)).total_seconds())


def jwt_value(token: str, key: str) -> str | None:
    parts = token.split(".")
    if len(parts) < 2:
        return None
    try:
        payload = parts[1].replace("-", "+").replace("_", "/")
        payload += "=" * (-len(payload) % 4)
        obj = json.loads(base64.urlsafe_b64decode(payload).decode("utf-8"))
    except (ValueError, UnicodeDecodeError, json.JSONDecodeError):
        return None
    return first_string(obj, [key]) if isinstance(obj, dict) else None


def chatgpt_account_id(raw: dict[str, Any]) -> str | None:
    direct = first_string(raw, [
        "account_id", "chatgpt_account_id", "id_token.chatgpt_account_id", "metadata.account_id"
    ])
    if direct:
        return direct
    token = first_string(raw, ["id_token", "metadata.id_token"])
    return jwt_value(token, "chatgpt_account_id") if token else None


def xai_user_id(raw: dict[str, Any]) -> str | None:
    direct = first_string(raw, [
        "sub", "subject", "user_id", "userId", "metadata.sub", "metadata.subject",
        "metadata.user_id", "metadata.userId", "attributes.sub", "oauth.sub",
        "oauth.subject", "user.sub", "user.id"
    ])
    if direct:
        return direct
    for path in ["access_token", "id_token", "metadata.access_token", "metadata.id_token"]:
        token = first_string(raw, [path])
        if token:
            value = jwt_value(token, "sub")
            if value:
                return value
    return None


def parse_provider(raw: str | None) -> tuple[str, str]:
    value = (raw or "").strip().lower()
    if value in {"codex", "openai", "chatgpt"}:
        return "codex", raw or ""
    if value in {"claude", "anthropic"}:
        return "claude", raw or ""
    if value in {"gemini", "gemini-cli", "aistudio"}:
        return "gemini-cli", raw or ""
    if value == "antigravity":
        return "antigravity", raw or ""
    if value in {"kimi", "kimi-ai", "moonshot"}:
        return "kimi", raw or ""
    if value in {"xai", "x-ai", "grok"}:
        return "xai", raw or ""
    return "unknown", raw or ""


def window(
    window_id: str,
    label: str,
    obj: dict[str, Any],
    prefix: str,
) -> dict[str, Any] | None:
    used = first_float(obj, [f"{prefix}.used_percent"])
    reset_seconds = first_float(obj, [f"{prefix}.reset_after_seconds"])
    limit_seconds = first_float(obj, [f"{prefix}.limit_window_seconds"])
    if used is None and reset_seconds is None and limit_seconds is None:
        return None
    return {
        "id": window_id,
        "label": "周额度" if (limit_seconds or 0) >= 86400 else label,
        "remainingPercent": clamp_percent(100 - used) if used is not None else None,
        "resetText": format_duration(reset_seconds) if reset_seconds is not None else None,
    }


def parse_codex(obj: dict[str, Any]) -> dict[str, Any]:
    windows = [
        window("5h", "5h", obj, "rate_limit.primary_window"),
        window("7d", "周额度", obj, "rate_limit.secondary_window"),
    ]
    windows = [item for item in windows if item]
    return {
        "planType": first_string(obj, ["plan_type", "planType", "account_plan.plan_type"]),
        "windows": windows,
        "error": None if windows else "empty quota payload",
    }


def utilization_window(
    window_id: str,
    label: str,
    used: float | None,
    resets_at: str | None,
) -> dict[str, Any] | None:
    if used is None and resets_at is None:
        return None
    return {
        "id": window_id,
        "label": label,
        "remainingPercent": clamp_percent(100 - used) if used is not None else None,
        "resetText": format_reset(resets_at),
    }


def parse_claude(obj: dict[str, Any]) -> dict[str, Any]:
    windows = [
        utilization_window(
            "5h", "5h",
            first_float(obj, ["five_hour.utilization", "five_hour.used_percentage", "rate_limits.five_hour.used_percentage"]),
            first_string(obj, ["five_hour.resets_at", "rate_limits.five_hour.resets_at"]),
        ),
        utilization_window(
            "7d", "周额度",
            first_float(obj, ["seven_day.utilization", "seven_day.used_percentage", "rate_limits.seven_day.used_percentage"]),
            first_string(obj, ["seven_day.resets_at", "rate_limits.seven_day.resets_at"]),
        ),
    ]
    windows = [item for item in windows if item]
    return {"planType": "claude", "windows": windows, "error": None if windows else "empty quota payload"}


def remaining_percent(obj: dict[str, Any]) -> float | None:
    for path in ["remainingFraction", "remaining_fraction", "remaining"]:
        value = first_float(obj, [path])
        if value is not None:
            return clamp_percent(value * 100 if value <= 1.5 else value)
    amount = first_float(obj, ["remainingAmount", "remaining_amount"])
    if amount is not None and amount <= 0:
        return 0.0
    return None


def short_model_name(raw: str) -> str:
    return raw.replace("gemini-", "").replace("-preview", "").replace("-thinking", "")


def parse_gemini(obj: dict[str, Any]) -> dict[str, Any]:
    buckets = obj.get("buckets")
    windows: list[dict[str, Any]] = []
    if isinstance(buckets, list):
        for bucket in buckets:
            if not isinstance(bucket, dict):
                continue
            model_id = first_string(bucket, ["modelId", "model_id"]) or "model"
            windows.append({
                "id": model_id,
                "label": short_model_name(model_id),
                "remainingPercent": remaining_percent(bucket),
                "resetText": format_reset(first_string(bucket, ["resetTime", "reset_time"])),
            })
    if len(windows) > 6:
        windows.sort(key=lambda item: item["remainingPercent"] if item["remainingPercent"] is not None else 999)
        windows = windows[:6]
    return {"planType": None, "windows": windows, "error": None if windows else "empty quota payload"}


def normalized_window_name(raw: str | None) -> str:
    return (raw or "").strip().replace("_", "-").lower()


def is_five_hour(raw: str | None) -> bool:
    value = normalized_window_name(raw)
    return value in {"5h", "five-hour", "fivehour"} or "5-hour" in value


def is_weekly(raw: str | None) -> bool:
    value = normalized_window_name(raw)
    return value in {"7d", "7-day", "7day", "seven-day", "sevenday", "weekly", "week"} \
        or "7-day" in value or "seven-day" in value or "weekly" in value


def grouped_google_window(groups: Any, window_id: str, label: str, matcher: Callable[[str | None], bool]) -> dict[str, Any] | None:
    remainings: list[float] = []
    reset: str | None = None
    if not isinstance(groups, list):
        return None
    for group in groups:
        if not isinstance(group, dict):
            continue
        buckets = group.get("buckets")
        if not isinstance(buckets, list):
            continue
        for bucket in buckets:
            if not isinstance(bucket, dict) or not matcher(first_string(bucket, ["window"])):
                continue
            value = remaining_percent(bucket)
            if value is not None:
                remainings.append(value)
            if reset is None:
                reset = format_reset(first_string(bucket, ["resetTime", "reset_time"]))
    if not remainings:
        return None
    return {
        "id": window_id,
        "label": label,
        "remainingPercent": sum(remainings) / len(remainings),
        "resetText": reset,
    }


def parse_google_assist_tier(obj: dict[str, Any]) -> str | None:
    raw = first_string(obj, ["currentTier.name", "currentTier.id", "paidTier.name", "paidTier.id"])
    if not raw:
        return None
    normalized = raw.strip().replace("_", "-").replace(" ", "-").lower()
    return {
        "plus": "Plus", "pro": "Pro", "prolite": "Pro Lite", "pro-lite": "Pro Lite",
        "ultra": "Ultra", "antigravity-ultra": "Ultra", "free": "Free",
        "free-tier": "Free", "legacy": "Free", "legacy-tier": "Free", "standard": "Standard",
    }.get(normalized, raw.replace("_", " ").title())


def parse_antigravity(obj: dict[str, Any]) -> dict[str, Any]:
    groups = obj.get("groups")
    windows = [
        grouped_google_window(groups, "5h", "5h", is_five_hour),
        grouped_google_window(groups, "7d", "周额度", is_weekly),
    ]
    if not any(windows):
        models = obj.get("models")
        if isinstance(models, dict):
            remainings: list[float] = []
            reset: str | None = None
            for entry in models.values():
                if not isinstance(entry, dict):
                    continue
                quota = entry.get("quotaInfo") or entry.get("quota_info") or {}
                if not isinstance(quota, dict):
                    continue
                value = remaining_percent(quota)
                if value is not None:
                    remainings.append(value)
                if reset is None:
                    reset = format_reset(first_string(quota, ["resetTime", "reset_time"]))
            if remainings:
                windows = [{
                    "id": "5h", "label": "5h",
                    "remainingPercent": sum(remainings) / len(remainings),
                    "resetText": reset,
                }, None]
    windows = [item for item in windows if item]
    return {
        "planType": parse_google_assist_tier(obj),
        "windows": windows,
        "error": None if windows else "empty quota payload",
    }


def xai_cents(obj: dict[str, Any], paths: list[str]) -> float | None:
    for path in paths:
        value = first_value(obj, [path])
        if isinstance(value, dict):
            value = value.get("val")
        if isinstance(value, (int, float)) and not isinstance(value, bool):
            return float(value)
        if isinstance(value, str):
            try:
                return float(value)
            except ValueError:
                pass
    return None


def xai_plan(obj: dict[str, Any]) -> str | None:
    monthly_limit = xai_cents(obj, ["monthlyLimit", "monthly_limit"])
    if monthly_limit == 15000:
        return "SuperGrok"
    if monthly_limit == 150000:
        return "SuperGrok Heavy"
    raw = first_string(obj, ["planType", "plan_type", "plan", "subscription", "product"])
    return raw.replace("_", " ").title() if raw else None


def parse_xai(obj: dict[str, Any]) -> dict[str, Any]:
    config = obj.get("config") if isinstance(obj.get("config"), dict) else obj
    period = config.get("currentPeriod") or config.get("current_period") or {}
    windows: list[dict[str, Any]] = []
    weekly_used = first_float(config, ["creditUsagePercent", "credit_usage_percent"])
    weekly_end = first_string(period, ["end"]) or first_string(config, ["periodEnd", "period_end"])
    if weekly_used is not None or period:
        windows.append({
            "id": "week", "label": "周额度",
            "remainingPercent": clamp_percent(100 - (weekly_used or 0)),
            "resetText": format_reset(weekly_end),
        })

    products = config.get("productUsage") or config.get("product_usage") or []
    if isinstance(products, list):
        for product in products:
            if not isinstance(product, dict):
                continue
            name = first_string(product, ["product"]) or "Grok"
            if name.strip().lower() == "grokbuild":
                continue
            used = first_float(product, ["usagePercent", "usage_percent"])
            if used is not None:
                windows.append({
                    "id": f"product-{name}", "label": name,
                    "remainingPercent": clamp_percent(100 - used), "resetText": None,
                })

    monthly_limit = xai_cents(config, ["monthlyLimit", "monthly_limit"])
    used_cents = xai_cents(config, ["used"])
    if monthly_limit and monthly_limit > 0 and used_cents is not None:
        included = min(used_cents, monthly_limit)
        windows.append({
            "id": "month", "label": "月额度",
            "remainingPercent": clamp_percent(100 - included / monthly_limit * 100),
            "resetText": format_reset(first_string(config, ["billingPeriodEnd", "billing_period_end"])),
        })

    return {
        "planType": xai_plan(config),
        "windows": windows,
        "error": None if windows else "empty quota payload",
    }


def kimi_window_label(window: dict[str, Any]) -> str | None:
    duration = first_float(window, ["duration"])
    unit = first_string(window, ["timeUnit", "time_unit"])
    if not duration or not unit:
        return None
    unit = unit.upper()
    if unit in {"TIME_UNIT_MINUTE", "MINUTE", "MINUTES"}:
        return f"{int(duration / 60)}h" if duration % 60 == 0 else f"{int(duration)}m"
    if unit in {"TIME_UNIT_HOUR", "HOUR", "HOURS"}:
        return f"{int(duration)}h"
    if unit in {"TIME_UNIT_DAY", "DAY", "DAYS"}:
        return "7d" if duration == 7 else f"{int(duration)}d"
    if unit in {"TIME_UNIT_WEEK", "WEEK", "WEEKS"}:
        return "7d" if duration == 1 else f"{int(duration)}w"
    return None


def kimi_remaining(detail: dict[str, Any]) -> float | None:
    limit = first_float(detail, ["limit"])
    if not limit or limit <= 0:
        return None
    remaining = first_float(detail, ["remaining"])
    if remaining is not None:
        return clamp_percent(remaining / limit * 100)
    used = first_float(detail, ["used"])
    return clamp_percent(100 - used / limit * 100) if used is not None else None


def kimi_plan(obj: dict[str, Any]) -> str | None:
    raw = first_string(obj, [
        "user.membership.level", "user.membership.name", "membership.level", "membership.name",
        "plan_type", "planType", "plan", "subscription", "tier", "level",
    ])
    if not raw:
        return None
    value = raw.strip()
    for prefix in ["LEVEL_", "PLAN_", "TIER_", "MEMBERSHIP_"]:
        if value.upper().startswith(prefix):
            value = value[len(prefix):]
            break
    return value.replace("_", " ").replace("-", " ").title()


def parse_kimi(obj: dict[str, Any]) -> dict[str, Any]:
    usage = obj.get("usage") if isinstance(obj.get("usage"), dict) else None
    usages = obj.get("usages") if isinstance(obj.get("usages"), list) else []
    top_limits = obj.get("limits") if isinstance(obj.get("limits"), list) else []
    detail: dict[str, Any] | None = None
    limits: list[Any] = top_limits
    if usage is not None:
        detail = usage.get("detail") if isinstance(usage.get("detail"), dict) else usage
        limits = usage.get("limits") if isinstance(usage.get("limits"), list) else top_limits
    elif usages:
        selected = next((item for item in usages if isinstance(item, dict) and (first_string(item, ["scope"]) or "").upper() == "FEATURE_CODING"), usages[0])
        if isinstance(selected, dict):
            detail = selected.get("detail") if isinstance(selected.get("detail"), dict) else None
            limits = selected.get("limits") if isinstance(selected.get("limits"), list) else top_limits
    elif isinstance(obj.get("detail"), dict):
        detail = obj["detail"]
    elif "limit" in obj:
        detail = obj

    windows: list[dict[str, Any]] = []
    if detail:
        value = kimi_remaining(detail)
        if value is not None:
            windows.append({
                "id": "7d", "label": "周额度", "remainingPercent": value,
                "resetText": format_reset(first_string(detail, ["resetTime", "reset_time", "resetAt", "reset_at"])),
            })

    for item in limits:
        if not isinstance(item, dict):
            continue
        quota_window = item.get("window")
        quota_detail = item.get("detail")
        if not isinstance(quota_window, dict) or not isinstance(quota_detail, dict):
            continue
        raw_label = kimi_window_label(quota_window)
        if not raw_label:
            continue
        weekly = is_weekly(raw_label)
        value = kimi_remaining(quota_detail)
        if value is None:
            continue
        window_id = "7d" if weekly else raw_label
        label = "周额度" if weekly else raw_label
        candidate = {
            "id": window_id, "label": label, "remainingPercent": value,
            "resetText": format_reset(first_string(quota_detail, ["resetTime", "reset_time", "resetAt", "reset_at"])),
        }
        existing = next((w for w in windows if w["id"] == window_id), None)
        if existing is None:
            windows.append(candidate)
        elif existing["remainingPercent"] != candidate["remainingPercent"] or existing["resetText"] != candidate["resetText"]:
            duplicate_count = sum(1 for item in windows if item["id"].startswith(label)) + 1
            candidate["id"] = f"{label}-{duplicate_count}"
            windows.append(candidate)

    return {"planType": kimi_plan(obj), "windows": windows, "error": None if windows else "empty quota payload"}


def merge_xai(weekly: dict[str, Any], monthly: dict[str, Any]) -> dict[str, Any]:
    by_id: dict[str, dict[str, Any]] = {}
    for item in weekly["windows"] + monthly["windows"]:
        by_id.setdefault(item["id"], item)
    extras = sorted(key for key in by_id if key.startswith("product-"))
    windows = [by_id[key] for key in ["week", *extras, "month"] if key in by_id]
    return {
        "planType": monthly.get("planType") or weekly.get("planType"),
        "windows": windows,
        "error": None if windows else (weekly.get("error") or monthly.get("error")),
    }


def make_account(raw: dict[str, Any]) -> dict[str, Any]:
    name = first_string(raw, ["name", "id"]) or "unknown"
    provider, provider_raw = parse_provider(first_string(raw, ["provider", "type"]))
    account_id = xai_user_id(raw) if provider == "xai" else chatgpt_account_id(raw)
    return {
        "id": first_string(raw, ["id", "auth_index", "name"]) or name,
        "authIndex": first_string(raw, ["auth_index", "authIndex", "id"]) or name,
        "name": name,
        "email": first_string(raw, ["email"]),
        "provider": provider,
        "providerRaw": provider_raw,
        "status": first_string(raw, ["status"]) or "unknown",
        "statusMessage": first_string(raw, ["status_message"]),
        "disabled": bool_value(raw.get("disabled")),
        "unavailable": bool_value(raw.get("unavailable")),
        "accountID": account_id,
        "projectID": first_string(raw, ["project_id", "metadata.project_id"]),
        "fileName": first_string(raw, ["name"]),
    }


def account_display_name(account: dict[str, Any]) -> str:
    return account.get("email") or account.get("name") or account.get("authIndex") or account.get("id") or ""


def account_sort_key(row: dict[str, Any]) -> tuple[str, float, str]:
    provider_names = {
        "codex": "Codex", "claude": "Claude", "gemini-cli": "Gemini CLI",
        "antigravity": "Agy", "kimi": "Kimi", "xai": "Grok", "unknown": "Other",
    }
    values = [w.get("remainingPercent") for w in row["snapshot"].get("windows", []) if w.get("remainingPercent") is not None]
    return (provider_names.get(row["account"]["provider"], "Other"), min(values, default=999), account_display_name(row).lower())


class ManagementAPI:
    def __init__(self, base_url: str, key: str, timeout: float = 30):
        self.base_url = base_url.strip()
        if not self.base_url:
            raise ValueError("CLIPROXY_BASE_URL is empty")
        if "://" not in self.base_url:
            self.base_url = "http://" + self.base_url
        self.base_url = self.base_url.rstrip("/")
        self.key = key.strip()
        self.timeout = timeout

    def request(self, path: str, method: str = "GET", payload: dict[str, Any] | None = None) -> Any:
        url = self.base_url + "/" + path.lstrip("/")
        headers = {
            "Authorization": f"Bearer {self.key}",
            "X-Management-Key": self.key,
            "User-Agent": "ClipBarBackend/1.0",
        }
        data = None
        if payload is not None:
            headers["Content-Type"] = "application/json"
            data = json.dumps(payload).encode("utf-8")
        request = urllib.request.Request(url, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as response:
                return response.status, response.read()
        except urllib.error.HTTPError as error:
            return error.code, error.read()

    def fetch_auth_files(self) -> list[dict[str, Any]]:
        status, data = self.request("/v0/management/auth-files")
        if not 200 <= status < 300:
            raise RuntimeError(f"CLIProxyAPI auth-files returned HTTP {status}")
        value = json.loads(data)
        if isinstance(value, dict) and isinstance(value.get("files"), list):
            return [item for item in value["files"] if isinstance(item, dict)]
        if isinstance(value, list):
            return [item for item in value if isinstance(item, dict)]
        raise RuntimeError("CLIProxyAPI auth-files returned invalid JSON")

    def download_auth_file(self, name: str) -> dict[str, Any] | None:
        query = urllib.parse.urlencode({"name": name})
        status, data = self.request(f"/v0/management/auth-files/download?{query}")
        if not 200 <= status < 300:
            return None
        value = json.loads(data)
        return value if isinstance(value, dict) else None

    def api_call(
        self,
        auth_index: str,
        method: str,
        url: str,
        headers: dict[str, str],
        body: str | None = None,
    ) -> tuple[int, str]:
        payload: dict[str, Any] = {
            "auth_index": auth_index,
            "method": method,
            "url": url,
            "header": headers,
        }
        if body is not None:
            payload["data"] = body
        status, data = self.request("/v0/management/api-call", method="POST", payload=payload)
        envelope = json_object(data)
        if envelope:
            envelope_status = first_float(envelope, ["status_code", "statusCode"])
            if envelope_status is not None and "body" in envelope:
                body_value = envelope["body"]
                if isinstance(body_value, str):
                    return int(envelope_status), body_value
                return int(envelope_status), json.dumps(body_value)
        return status, data.decode("utf-8", errors="replace")


def json_body(value: dict[str, Any]) -> str:
    return json.dumps(value, separators=(",", ":"))


class Collector:
    def __init__(self, api: ManagementAPI):
        self.api = api

    def collect(self) -> list[dict[str, Any]]:
        accounts = [make_account(raw) for raw in self.api.fetch_auth_files()]
        with ThreadPoolExecutor(max_workers=min(16, max(1, len(accounts)))) as pool:
            futures = [pool.submit(self.enrich_account, account) for account in accounts]
            accounts = [future.result() for future in as_completed(futures)]
        with ThreadPoolExecutor(max_workers=min(16, max(1, len(accounts)))) as pool:
            futures = [pool.submit(self.load_quota, account) for account in accounts]
            rows = [future.result() for future in as_completed(futures)]
        rows.sort(key=account_sort_key)
        return rows

    def enrich_account(self, account: dict[str, Any]) -> dict[str, Any]:
        needs_account_id = account["provider"] in {"codex", "xai"} and not account.get("accountID")
        needs_project_id = account["provider"] in {"gemini-cli", "antigravity"} and not account.get("projectID")
        if not (needs_account_id or needs_project_id) or not account.get("fileName"):
            return account
        downloaded = self.api.download_auth_file(account["fileName"])
        if not downloaded:
            return account
        updated = dict(account)
        if needs_account_id:
            updated["accountID"] = xai_user_id(downloaded) if account["provider"] == "xai" else chatgpt_account_id(downloaded)
        if needs_project_id:
            updated["projectID"] = first_string(downloaded, ["project_id", "metadata.project_id"])
        return updated

    def load_quota(self, account: dict[str, Any]) -> dict[str, Any]:
        try:
            snapshot = self.fetch_snapshot(account)
        except Exception as error:  # one broken account must not hide the others
            LOG.warning("quota failed for %s: %s", account_display_name(account), error)
            snapshot = {"planType": None, "windows": [], "error": str(error)}
        return {"account": account, "snapshot": snapshot}

    def fetch_snapshot(self, account: dict[str, Any]) -> dict[str, Any]:
        provider = account["provider"]
        if provider == "codex":
            account_id = account.get("accountID")
            if not account_id:
                return {"planType": None, "windows": [], "error": "missing chatgpt_account_id"}
            headers = {
                "Authorization": "Bearer $TOKEN$", "Content-Type": "application/json",
                "User-Agent": "codex_cli_rs/0.76.0 (Debian 13.0.0; x86_64) WindowsTerminal",
                "Chatgpt-Account-Id": account_id,
            }
            return self.decode(self.api.api_call(account["authIndex"], "GET", "https://chatgpt.com/backend-api/wham/usage", headers), parse_codex)
        if provider == "claude":
            return self.decode(self.api.api_call(account["authIndex"], "GET", "https://api.anthropic.com/api/oauth/usage", {
                "Authorization": "Bearer $TOKEN$", "Content-Type": "application/json", "anthropic-beta": "oauth-2025-04-20"
            }), parse_claude)
        if provider == "kimi":
            return self.decode(self.api.api_call(account["authIndex"], "GET", "https://api.kimi.com/coding/v1/usages", {
                "Authorization": "Bearer $TOKEN$", "Accept": "application/json", "Content-Type": "application/json", "X-Msh-Platform": "CLIProxyAPI"
            }), parse_kimi)
        if provider == "gemini-cli":
            project = self.google_project(account, {
                "ideType": "IDE_UNSPECIFIED", "platform": "PLATFORM_UNSPECIFIED", "pluginType": "GEMINI"
            })
            response = self.api.api_call(account["authIndex"], "POST", "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota", google_headers({
                "ideType": "IDE_UNSPECIFIED", "platform": "PLATFORM_UNSPECIFIED", "pluginType": "GEMINI"
            }), json_body({"project": project}))
            return self.decode(response, parse_gemini)
        if provider == "antigravity":
            metadata = {"ideType": "ANTIGRAVITY", "platform": "PLATFORM_UNSPECIFIED", "pluginType": "GEMINI"}
            project = self.google_project(account, metadata)
            headers = {
                "Authorization": "Bearer $TOKEN$", "Content-Type": "application/json",
                "User-Agent": "antigravity/cli/1.0.13 (aidev_client; os_type=darwin; arch=arm64)",
            }
            last_error = "retrieveUserQuotaSummary failed"
            endpoints = [
                "https://daily-cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary",
                "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary",
                "https://cloudcode-pa.googleapis.com/v1internal:fetchAvailableModels",
                "https://daily-cloudcode-pa.googleapis.com/v1internal:fetchAvailableModels",
            ]
            for endpoint in endpoints:
                status, body = self.api.api_call(account["authIndex"], "POST", endpoint, headers, json_body({"project": project}))
                if 200 <= status < 300:
                    obj = json_object(body.encode())
                    if obj:
                        snapshot = parse_antigravity(obj)
                        if any(w.get("remainingPercent") is not None for w in snapshot["windows"]):
                            return snapshot
                        last_error = snapshot.get("error") or "empty quota"
                else:
                    last_error = body or f"HTTP {status}"
            return {"planType": None, "windows": [], "error": last_error}
        if provider == "xai":
            headers = {
                "Authorization": "Bearer $TOKEN$", "x-xai-token-auth": "xai-grok-cli",
                "x-grok-client-version": "0.2.91", "accept": "*/*",
                "user-agent": "grok-pager/0.2.91 grok-shell/0.2.91 (macos; aarch64)",
            }
            if account.get("accountID"):
                headers["x-userid"] = account["accountID"]
            weekly = self.api.api_call(account["authIndex"], "GET", "https://cli-chat-proxy.grok.com/v1/billing?format=credits", headers)
            monthly = self.api.api_call(account["authIndex"], "GET", "https://cli-chat-proxy.grok.com/v1/billing", headers)
            weekly_snapshot = self.snapshot_if_ok(weekly, parse_xai)
            monthly_snapshot = self.snapshot_if_ok(monthly, parse_xai)
            if weekly_snapshot and monthly_snapshot:
                snapshot = merge_xai(weekly_snapshot, monthly_snapshot)
            elif weekly_snapshot:
                snapshot = weekly_snapshot
            elif monthly_snapshot:
                snapshot = monthly_snapshot
            else:
                status, body = weekly if not 200 <= weekly[0] < 300 else monthly
                raise RuntimeError(f"HTTP {status}: {body[:160]}")
            if not snapshot.get("planType"):
                obj = json_object(monthly[1].encode())
                if obj:
                    snapshot["planType"] = parse_xai(obj).get("planType")
            return snapshot
        return {"planType": None, "windows": [], "error": "Live quota is not available for this provider yet."}

    def google_project(self, account: dict[str, Any], metadata: dict[str, str]) -> str:
        if account.get("projectID"):
            return account["projectID"]
        response = self.api.api_call(
            account["authIndex"], "POST", "https://cloudcode-pa.googleapis.com/v1internal:loadCodeAssist",
            google_headers(metadata), json_body({"metadata": metadata})
        )
        status, body = response
        obj = json_object(body.encode())
        project = first_string(obj or {}, ["cloudaicompanionProject", "cloudaicompanionProject.id"])
        if not 200 <= status < 300 or not project:
            raise RuntimeError(f"loadCodeAssist returned HTTP {status}")
        return project

    @staticmethod
    def decode(response: tuple[int, str], parser: Callable[[dict[str, Any]], dict[str, Any]]) -> dict[str, Any]:
        status, body = response
        if not 200 <= status < 300:
            raise RuntimeError(f"HTTP {status}: {body[:160]}")
        obj = json_object(body.encode())
        if obj is None:
            raise RuntimeError("invalid quota response")
        return parser(obj)

    @staticmethod
    def snapshot_if_ok(response: tuple[int, str], parser: Callable[[dict[str, Any]], dict[str, Any]]) -> dict[str, Any] | None:
        status, body = response
        if not 200 <= status < 300:
            return None
        obj = json_object(body.encode())
        if obj is None:
            return None
        snapshot = parser(obj)
        return snapshot if any(w.get("remainingPercent") is not None for w in snapshot["windows"]) else None


def google_headers(metadata: dict[str, str]) -> dict[str, str]:
    return {
        "Authorization": "Bearer $TOKEN$",
        "Content-Type": "application/json",
        "User-Agent": "google-api-nodejs-client/9.15.1",
        "X-Goog-Api-Client": "google-cloud-sdk vscode_cloudshelleditor/0.1",
        "Client-Metadata": json.dumps(metadata, separators=(",", ":")),
    }


class SnapshotStore:
    def __init__(self, path: str):
        self.path = Path(path)
        self.lock = threading.Lock()
        self.data: dict[str, Any] = {
            "schema_version": 1,
            "last_updated_at": None,
            "last_attempt_at": None,
            "accounts": [],
            "error": "not polled yet",
        }
        self.load()

    def load(self) -> None:
        try:
            loaded = json.loads(self.path.read_text(encoding="utf-8"))
            if isinstance(loaded, dict) and isinstance(loaded.get("accounts"), list):
                self.data.update(loaded)
        except (FileNotFoundError, OSError, ValueError):
            return

    def read(self) -> dict[str, Any]:
        with self.lock:
            return json.loads(json.dumps(self.data))

    def record_success(self, accounts: list[dict[str, Any]]) -> None:
        with self.lock:
            self.data = {
                "schema_version": 1,
                "last_updated_at": now_iso(),
                "last_attempt_at": now_iso(),
                "accounts": accounts,
                "error": None,
            }
            self.write_locked()

    def record_failure(self, error: str) -> None:
        with self.lock:
            self.data["last_attempt_at"] = now_iso()
            self.data["error"] = error
            self.write_locked()

    def write_locked(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        temporary = self.path.with_suffix(self.path.suffix + ".tmp")
        temporary.write_text(json.dumps(self.data, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
        temporary.replace(self.path)


class BackendSettingsStore:
    def __init__(self, path: str, default_interval: int):
        self.path = Path(path)
        self.lock = threading.Lock()
        self.interval = nearest_refresh_interval(default_interval)
        self.load()

    def load(self) -> None:
        try:
            loaded = json.loads(self.path.read_text(encoding="utf-8"))
            value = loaded.get("refresh_interval_seconds") if isinstance(loaded, dict) else None
            if isinstance(value, int) and not isinstance(value, bool):
                self.interval = nearest_refresh_interval(value)
        except (FileNotFoundError, OSError, ValueError):
            return

    def read_interval(self) -> int:
        with self.lock:
            return self.interval

    def update_interval(self, seconds: int) -> int:
        if isinstance(seconds, bool) or not isinstance(seconds, int):
            raise ValueError("refresh_interval_seconds must be an integer")
        interval = nearest_refresh_interval(seconds)
        with self.lock:
            self.interval = interval
            self.path.parent.mkdir(parents=True, exist_ok=True)
            temporary = self.path.with_suffix(self.path.suffix + ".tmp")
            temporary.write_text(
                json.dumps({"refresh_interval_seconds": interval}, separators=(",", ":")),
                encoding="utf-8",
            )
            temporary.replace(self.path)
        return interval


class Poller:
    def __init__(self, store: SnapshotStore, collector: Collector, interval: int):
        self.store = store
        self.collector = collector
        self.interval = max(30, interval)
        self.stop_event = threading.Event()
        self.wake_event = threading.Event()
        self.refresh_lock = threading.Lock()
        self.interval_lock = threading.Lock()
        self.thread = threading.Thread(target=self.run, name="quota-poller", daemon=True)

    def start(self) -> None:
        self.thread.start()

    def stop(self) -> None:
        self.stop_event.set()
        self.wake_event.set()
        self.thread.join(timeout=5)

    def set_interval(self, seconds: int) -> None:
        with self.interval_lock:
            self.interval = max(30, seconds)
        self.wake_event.set()

    def get_interval(self) -> int:
        with self.interval_lock:
            return self.interval

    def refresh_once(self) -> bool:
        with self.refresh_lock:
            try:
                accounts = self.collector.collect()
                self.store.record_success(accounts)
                LOG.info("stored quota snapshot for %d accounts", len(accounts))
                return True
            except Exception as error:
                LOG.exception("quota poll failed")
                self.store.record_failure(str(error))
                return False

    def run(self) -> None:
        while not self.stop_event.is_set():
            started = time.monotonic()
            self.refresh_once()
            delay = max(1.0, self.get_interval() - (time.monotonic() - started))
            self.wake_event.wait(delay)
            self.wake_event.clear()


class RequestHandler(BaseHTTPRequestHandler):
    server_version = "ClipBarBackend/1.0"

    def log_message(self, fmt: str, *args: Any) -> None:
        LOG.info("%s - %s", self.address_string(), fmt % args)

    @property
    def app(self) -> "BackendServer":
        return self.server.app  # type: ignore[attr-defined]

    def snapshot_payload(self) -> dict[str, Any]:
        data = self.app.store.read()
        return {
            "schema_version": data.get("schema_version", 1),
            "last_updated_at": data.get("last_updated_at"),
            "last_attempt_at": data.get("last_attempt_at"),
            "accounts": data.get("accounts", []),
            "error": data.get("error"),
        }

    def do_GET(self) -> None:
        if self.path == "/healthz":
            snapshot = self.app.store.read()
            self.send_json(200, {
                "ok": True,
                "last_updated_at": snapshot.get("last_updated_at"),
                "last_attempt_at": snapshot.get("last_attempt_at"),
                "account_count": len(snapshot.get("accounts", [])),
                "error": snapshot.get("error"),
            })
            return
        if self.path in {"/v1/snapshot", "/v1/settings"}:
            if not self.app.authorized(self.headers):
                self.send_json(401, {"error": "unauthorized"})
                return
            if self.path == "/v1/snapshot":
                self.send_json(200, self.snapshot_payload())
            else:
                self.send_json(200, self.app.settings_payload())
            return
        self.send_json(404, {"error": "not found"})

    def do_PUT(self) -> None:
        if self.path != "/v1/settings":
            self.send_json(404, {"error": "not found"})
            return
        if not self.app.authorized(self.headers):
            self.send_json(401, {"error": "unauthorized"})
            return
        try:
            payload = self.read_json()
            seconds = payload["refresh_interval_seconds"]
            if isinstance(seconds, bool) or not isinstance(seconds, int):
                raise ValueError
            interval = self.app.update_refresh_interval(seconds)
        except (KeyError, TypeError, ValueError, json.JSONDecodeError):
            self.send_json(400, {"error": "refresh_interval_seconds must be an integer"})
            return
        self.send_json(200, {"refresh_interval_seconds": interval})

    def do_POST(self) -> None:
        if self.path != "/v1/refresh":
            self.send_json(404, {"error": "not found"})
            return
        if not self.app.authorized(self.headers):
            self.send_json(401, {"error": "unauthorized"})
            return
        if self.app.poller is None:
            self.send_json(503, {"error": "poller unavailable"})
            return
        success = self.app.poller.refresh_once()
        self.send_json(200 if success else 502, self.snapshot_payload())

    def do_HEAD(self) -> None:
        if self.path == "/healthz":
            self.send_response(200)
            self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()

    def read_json(self) -> dict[str, Any]:
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError as error:
            raise ValueError from error
        if length <= 0 or length > 4096:
            raise ValueError
        value = json.loads(self.rfile.read(length))
        if not isinstance(value, dict):
            raise ValueError
        return value

    def send_json(self, status: int, value: dict[str, Any]) -> None:
        body = json.dumps(value, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)


class BackendServer(ThreadingHTTPServer):
    def __init__(
        self,
        address: tuple[str, int],
        store: SnapshotStore,
        token: str,
        poller: Poller | None = None,
        settings_store: BackendSettingsStore | None = None,
    ):
        super().__init__(address, RequestHandler)
        self.store = store
        self.token = token.strip()
        self.poller = poller
        self.settings_store = settings_store
        self.app = self

    def settings_payload(self) -> dict[str, Any]:
        if self.settings_store is not None:
            interval = self.settings_store.read_interval()
        elif self.poller is not None:
            interval = self.poller.get_interval()
        else:
            interval = 600
        return {"refresh_interval_seconds": interval}

    def update_refresh_interval(self, seconds: int) -> int:
        if self.settings_store is not None:
            interval = self.settings_store.update_interval(seconds)
        else:
            interval = nearest_refresh_interval(seconds)
        if self.poller is not None:
            self.poller.set_interval(interval)
        return interval

    def authorized(self, headers: Any) -> bool:
        if not self.token:
            return False
        authorization = headers.get("Authorization", "")
        bearer = authorization[7:].strip() if authorization.lower().startswith("bearer ") else ""
        return bearer == self.token or headers.get("X-ClipBar-Token", "") == self.token


def env_int(name: str, default: int) -> int:
    try:
        return int(os.environ.get(name, str(default)))
    except ValueError:
        return default


def main() -> None:
    logging.basicConfig(level=os.environ.get("LOG_LEVEL", "INFO").upper(), format="%(asctime)s %(levelname)s %(message)s")
    cliproxy_key = os.environ.get("CLIPROXY_MANAGEMENT_KEY", "").strip()
    access_token = os.environ.get("CLIPBAR_ACCESS_TOKEN", "").strip()
    if not cliproxy_key:
        raise SystemExit("CLIPROXY_MANAGEMENT_KEY is required")
    if not access_token:
        raise SystemExit("CLIPBAR_ACCESS_TOKEN is required")

    data_path = os.environ.get("DATA_PATH", "/data/snapshot.json")
    store = SnapshotStore(data_path)
    settings_path = os.environ.get("SETTINGS_PATH", str(Path(data_path).with_name("settings.json")))
    settings_store = BackendSettingsStore(settings_path, env_int("POLL_INTERVAL_SECONDS", 600))
    api = ManagementAPI(os.environ.get("CLIPROXY_BASE_URL", "http://127.0.0.1:8317"), cliproxy_key)
    poller = Poller(store, Collector(api), settings_store.read_interval())
    server = BackendServer(
        (os.environ.get("HOST", "0.0.0.0"), env_int("PORT", 8080)),
        store,
        access_token,
        poller,
        settings_store,
    )

    def stop(_: int, __: Any) -> None:
        poller.stop()
        threading.Thread(target=server.shutdown, daemon=True).start()

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    poller.start()
    LOG.info("ClipBar backend listening on %s:%s", server.server_address[0], server.server_address[1])
    try:
        server.serve_forever()
    finally:
        poller.stop()
        server.server_close()


if __name__ == "__main__":
    main()
