"""Sales aggregation for the admin dashboard."""
from collections import defaultdict
from datetime import datetime, timedelta

from ..config import Config
from . import orders as orders_repo


def daily_summary(order_date):
    """End-of-day totals for a single YYYY-MM-DD date."""
    orders = orders_repo.list_by_date(order_date)

    order_count = 0
    gross_sales = 0
    by_category = defaultdict(int)
    by_payment = defaultdict(int)
    item_qty = defaultdict(int)
    item_rev = defaultdict(int)

    for o in orders:
        if o.get("status") not in Config.SALES_STATUSES:
            continue  # skip cancelled
        order_count += 1
        gross_sales += int(o.get("total", 0))
        by_payment[o.get("payment_method", "cash")] += int(o.get("total", 0))
        for line in o.get("items", []):
            cat = line.get("category", "other")
            by_category[cat] += int(line.get("line_total", 0))
            item_qty[line["name"]] += int(line.get("qty", 0))
            item_rev[line["name"]] += int(line.get("line_total", 0))

    top_items = sorted(
        (
            {"name": n, "qty": item_qty[n], "revenue": item_rev[n]}
            for n in item_qty
        ),
        key=lambda x: x["revenue"],
        reverse=True,
    )[:5]

    return {
        "date": order_date,
        "order_count": order_count,
        "gross_sales": gross_sales,
        "by_category": dict(by_category),
        "by_payment": dict(by_payment),
        "top_items": top_items,
    }


def billing_summary(order_date=None):
    """Owner billing: collected orders grouped by day, with paid/unpaid totals.

    order_date: optional YYYY-MM-DD to restrict the view to a single day.
    """
    if order_date:
        orders = [o for o in orders_repo.list_by_date(order_date)
                  if o.get("status") == "collected"]
    else:
        orders = [o for o in orders_repo.list_orders()
                  if o.get("status") == "collected"]

    days = defaultdict(list)
    for o in orders:
        d = o.get("order_date") or (o.get("created_at") or "")[:10]
        days[d].append(o)

    def amount_paid(o):
        # New orders carry paid_amount; older ones can be inferred.
        if o.get("paid_amount") is not None:
            return int(o["paid_amount"])
        return int(o.get("total", 0)) if o.get("payment_status") == "paid" else 0

    day_list = []
    for d in sorted(days, reverse=True):
        day_orders = days[d]
        total = sum(int(o.get("total", 0)) for o in day_orders)
        paid = sum(amount_paid(o) for o in day_orders)
        by_payment = defaultdict(int)
        for o in day_orders:
            by_payment[o.get("payment_method", "cash")] += int(o.get("total", 0))
        day_list.append({
            "date": d,
            "orders": day_orders,
            "order_count": len(day_orders),
            "total": total,
            "paid": paid,
            "unpaid": total - paid,
            "by_payment": dict(by_payment),
        })

    return {
        "days": day_list,
        "summary": {
            "order_count": sum(d["order_count"] for d in day_list),
            "total": sum(d["total"] for d in day_list),
            "paid": sum(d["paid"] for d in day_list),
            "unpaid": sum(d["unpaid"] for d in day_list),
        },
    }


def top_items(days=7, top_n=10):
    """Most-ordered items over the last N days, by item_id.

    Used by the AI recommender as a popularity signal and fallback.
    Returns [{"item_id", "name", "qty"}], best first; [] when there is
    no sales history yet.
    """
    today = datetime.now().date()
    qty = defaultdict(int)
    name_by_id = {}
    for offset in range(days):
        day = (today - timedelta(days=offset)).strftime("%Y-%m-%d")
        for o in orders_repo.list_by_date(day):
            if o.get("status") not in Config.SALES_STATUSES:
                continue  # skip cancelled
            for line in o.get("items", []):
                item_id = line.get("item_id")
                if not item_id:
                    continue
                qty[item_id] += int(line.get("qty", 0))
                name_by_id.setdefault(item_id, line.get("name", item_id))

    ranked = sorted(
        ({"item_id": i, "name": name_by_id[i], "qty": q} for i, q in qty.items()),
        key=lambda x: x["qty"],
        reverse=True,
    )
    return ranked[:top_n]


def range_summary(date_from, date_to):
    """A daily series between two YYYY-MM-DD dates (inclusive)."""
    start = datetime.strptime(date_from, "%Y-%m-%d").date()
    end = datetime.strptime(date_to, "%Y-%m-%d").date()
    if end < start:
        start, end = end, start

    series = []
    day = start
    while day <= end:
        series.append(daily_summary(day.strftime("%Y-%m-%d")))
        day += timedelta(days=1)
    return series
