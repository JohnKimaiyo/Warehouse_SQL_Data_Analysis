
-- =====================================================================
-- SQL PRACTICE QUERIES FOR WAREHOUSE MANAGEMENT DATASETS
-- =====================================================================

-- 1. BASIC QUERIES
-- =================
-- List all delivered items
SELECT * FROM commodities_delivered LIMIT 10;

-- List all issued items
SELECT * FROM commodities_issued LIMIT 10;

-- Count total items delivered
SELECT COUNT(*) as TotalDeliveries FROM commodities_delivered;

-- Count total items issued
SELECT COUNT(*) as TotalIssued FROM commodities_issued;

-- 2. SUBQUERIES PRACTICE
-- =======================
-- Find items delivered but not issued
SELECT d.* 
FROM commodities_delivered d
WHERE d.LPO_Number NOT IN (
    SELECT DISTINCT LPO_Number 
    FROM commodities_issued
)
ORDER BY d.ReceiptDate DESC;

-- Find items that have been issued more than once
SELECT LPO_Number, ItemCode, COUNT(*) as IssueCount
FROM commodities_issued
WHERE LPO_Number IN (
    SELECT LPO_Number 
    FROM commodities_delivered
    WHERE Level1Category = 'Pharmaceuticals'
)
GROUP BY LPO_Number, ItemCode
HAVING COUNT(*) > 1;

-- Find average unit cost by category using subquery
SELECT 
    Level1Category,
    AVG(UnitCost) as avg_cost,
    (SELECT AVG(UnitCost) FROM commodities_delivered) as overall_avg
FROM commodities_delivered
GROUP BY Level1Category;

-- 3. JOINS PRACTICE
-- ==================
-- INNER JOIN: Find complete delivery-issuance pairs
SELECT 
    d.LPO_Number,
    d.ItemCode,
    d.ReceiptDate,
    d.SupplierName,
    i.IssueDate,
    i.IssuedTo,
    i.IssuedQuantity,
    d.QtyOnHand
FROM commodities_delivered d
INNER JOIN commodities_issued i ON d.LPO_Number = i.LPO_Number;

-- LEFT JOIN: All deliveries with matching issuances
SELECT 
    d.LPO_Number,
    d.ItemCode,
    d.QtyOnHand,
    COALESCE(SUM(i.IssuedQuantity), 0) as total_issued,
    d.QtyOnHand - COALESCE(SUM(i.IssuedQuantity), 0) as remaining_stock
FROM commodities_delivered d
LEFT JOIN commodities_issued i ON d.LPO_Number = i.LPO_Number
GROUP BY d.LPO_Number, d.ItemCode, d.QtyOnHand
ORDER BY remaining_stock DESC;

-- 4. WINDOW FUNCTIONS PRACTICE
-- =============================
-- Rank suppliers by total value delivered
SELECT 
    SupplierName,
    COUNT(*) as delivery_count,
    SUM(TotalSales) as total_value,
    RANK() OVER (ORDER BY SUM(TotalSales) DESC) as supplier_rank,
    ROW_NUMBER() OVER (ORDER BY SUM(TotalSales) DESC) as row_num
FROM commodities_delivered
GROUP BY SupplierName;

-- Running total of issued quantities by date
SELECT 
    IssueDate,
    IssuedQuantity,
    TotalCost,
    SUM(IssuedQuantity) OVER (ORDER BY IssueDate) as running_quantity,
    SUM(TotalCost) OVER (ORDER BY IssueDate) as running_value,
    AVG(IssuedQuantity) OVER (ORDER BY IssueDate ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) as weekly_avg_quantity
FROM commodities_issued
ORDER BY IssueDate;

-- 5. QUERY OPTIMIZATION PRACTICE
-- ===============================
-- Using EXISTS instead of IN
SELECT d.*
FROM commodities_delivered d
WHERE EXISTS (
    SELECT 1 
    FROM commodities_issued i 
    WHERE i.LPO_Number = d.LPO_Number
    AND i.IssueDate >= DATE('now', '-30 days')
);

-- Materialized query using CTE
WITH monthly_summary AS (
    SELECT 
        strftime('%Y-%m', ReceiptDate) as delivery_month,
        Level1Category,
        COUNT(*) as delivery_count,
        SUM(TotalSales) as monthly_value
    FROM commodities_delivered
    GROUP BY strftime('%Y-%m', ReceiptDate), Level1Category
)
SELECT 
    delivery_month,
    Level1Category,
    delivery_count,
    monthly_value,
    SUM(monthly_value) OVER (PARTITION BY Level1Category ORDER BY delivery_month) as ytd_value
FROM monthly_summary
ORDER BY delivery_month DESC, monthly_value DESC;

-- 6. RECURSIVE CTE PRACTICE (For databases that support it)
-- ============================================================
-- Note: SQLite supports recursive CTEs
-- Generate a date series for the last 30 days
WITH RECURSIVE date_series AS (
    SELECT DATE('now', '-30 days') as report_date
    UNION ALL
    SELECT DATE(report_date, '+1 day')
    FROM date_series
    WHERE report_date < DATE('now')
)
SELECT 
    ds.report_date,
    COUNT(DISTINCT d.LPO_Number) as deliveries_on_date,
    COUNT(DISTINCT i.IssueID) as issues_on_date
FROM date_series ds
LEFT JOIN commodities_delivered d ON ds.report_date = d.ReceiptDate
LEFT JOIN commodities_issued i ON ds.report_date = i.IssueDate
GROUP BY ds.report_date
ORDER BY ds.report_date;

-- 7. ADVANCED ANALYTICS
-- ======================
-- Stock turnover rate by category
SELECT 
    d.Level1Category,
    SUM(d.QtyOnHand) as total_stock,
    SUM(i.IssuedQuantity) as total_issued,
    CASE 
        WHEN SUM(d.QtyOnHand) > 0 
        THEN CAST(SUM(i.IssuedQuantity) AS FLOAT) / SUM(d.QtyOnHand) 
        ELSE 0 
    END as turnover_rate
FROM commodities_delivered d
LEFT JOIN commodities_issued i ON d.LPO_Number = i.LPO_Number
GROUP BY d.Level1Category
ORDER BY turnover_rate DESC;

-- Expiring soon analysis
SELECT 
    Level1Category,
    Level2Category,
    ItemCode,
    BatchNo,
    ExpiryDate,
    QtyOnHand,
    UnitCost,
    QtyOnHand * UnitCost as stock_value,
    julianday(ExpiryDate) - julianday('now') as days_to_expiry
FROM commodities_delivered
WHERE ExpiryDate BETWEEN DATE('now') AND DATE('now', '+90 days')
ORDER BY days_to_expiry, stock_value DESC;
