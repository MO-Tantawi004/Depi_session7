-- Customer activity log
CREATE TABLE sales.customer_log (
    log_id INT IDENTITY(1,1) PRIMARY KEY,
    customer_id INT,
    action VARCHAR(50),
    log_date DATETIME DEFAULT GETDATE()
);

-- Price history tracking
CREATE TABLE production.price_history (
    history_id INT IDENTITY(1,1) PRIMARY KEY,
    product_id INT,
    old_price DECIMAL(10,2),
    new_price DECIMAL(10,2),
    change_date DATETIME DEFAULT GETDATE(),
    changed_by VARCHAR(100)
);

-- Order audit trail
CREATE TABLE sales.order_audit (
    audit_id INT IDENTITY(1,1) PRIMARY KEY,
    order_id INT,
    customer_id INT,
    store_id INT,
    staff_id INT,
    order_date DATE,
    audit_timestamp DATETIME DEFAULT GETDATE()
);



---------1.
CREATE NONCLUSTERED INDEX idx_customers_email
ON sales.customers (email);

---------2.

CREATE NONCLUSTERED INDEX idx_products_category_brand
ON production.products (category_id, brand_id);

---------3.

CREATE NONCLUSTERED INDEX idx_orders_orderdate
ON sales.orders (order_date)
INCLUDE (customer_id, store_id, order_status);

---------4**********


CREATE TRIGGER trg_customer_insert_log
ON sales.customers
AFTER INSERT
AS
BEGIN
    INSERT INTO sales.customer_log (customer_id, action)
    SELECT customer_id, 'Welcome - New Customer'
    FROM inserted;
END;

-------5.

CREATE TRIGGER trg_product_price_change
ON production.products
AFTER UPDATE
AS
BEGIN
    INSERT INTO production.price_history (product_id, old_price, new_price, changed_by)
    SELECT i.product_id, d.list_price, i.list_price, SYSTEM_USER
    FROM inserted i
    JOIN deleted d ON i.product_id = d.product_id
    WHERE i.list_price <> d.list_price;
END;

------6.

CREATE TRIGGER trg_prevent_delete_category_with_products
ON production.categories
INSTEAD OF DELETE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM deleted d
        JOIN production.products p ON d.category_id = p.category_id
    )
    BEGIN
        RAISERROR ('Cannot delete category because it has associated products.', 16, 1);
        ROLLBACK;
    END
    ELSE
    BEGIN
        DELETE FROM production.categories
        WHERE category_id IN (SELECT category_id FROM deleted);
    END
END;


-----7

CREATE TRIGGER trg_reduce_stock_on_order
ON sales.order_items
AFTER INSERT
AS
BEGIN
    UPDATE s
    SET s.quantity = s.quantity - i.quantity
    FROM production.stocks s
    JOIN inserted i
        ON s.store_id = (SELECT store_id FROM sales.orders WHERE order_id = i.order_id)
        AND s.product_id = i.product_id;
END;

----8

CREATE TRIGGER trg_log_order_creation
ON sales.orders
AFTER INSERT
AS
BEGIN
    INSERT INTO sales.order_audit (order_id, customer_id, store_id, staff_id, order_date)
    SELECT order_id, customer_id, store_id, staff_id, order_date
    FROM inserted;
END;