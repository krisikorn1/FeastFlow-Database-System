-- ============================================
-- FEASTFLOW - SQL SCRIPTS WITH VARIABLES
-- Using parameterized queries for demonstration
-- ============================================

-- Drop existing tables if they exist
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS menu_items CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- ============================================
-- TABLE CREATION
-- ============================================

-- Table 1: Users
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('admin', 'kitchen'))
);

-- Table 2: Categories
CREATE TABLE categories (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(50) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table 3: Menu Items
CREATE TABLE menu_items (
    item_id SERIAL PRIMARY KEY,
    item_name VARCHAR(100) NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    category_id INTEGER NOT NULL,
    image_url TEXT,
    is_available BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE CASCADE
);

-- Table 4: Orders
CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    table_number INTEGER NOT NULL,
    total_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'New',
    order_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (status IN ('New', 'In Progress', 'Fulfilled'))
);

-- Table 5: Order Items
CREATE TABLE order_items (
    order_item_id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL,
    item_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    item_price DECIMAL(10, 2) NOT NULL,
    subtotal DECIMAL(10, 2) GENERATED ALWAYS AS (quantity * item_price) STORED,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (item_id) REFERENCES menu_items(item_id) ON DELETE CASCADE
);

-- Insert sample data
-- Insert users with variables
-- Parameters: $1 = username, $2 = password, $3 = role
INSERT INTO users (username, password, role) VALUES ($1, $2, $3);
-- Example 1: $1='admin', $2='admin123', $3='admin'
-- Example 2: $1='kitchen', $2='kitchen123', $3='kitchen'

-- Insert categories with variables
-- Parameters: $1 = category_name
INSERT INTO categories (category_name) VALUES ($1);
-- Example 1: $1='Appetizers'
-- Example 2: $1='Main Dishes'
-- Example 3: $1='Drinks'

-- Insert menu items with variables
-- Parameters: $1 = item_name, $2 = price, $3 = category_id, $4 = image_url
INSERT INTO menu_items (item_name, price, category_id, image_url) VALUES ($1, $2, $3, $4);
-- Example 1: $1='Cheese Burger', $2=12.00, $3=2, $4='picture/burger.jpg'
-- Example 2: $1='French Fries', $2=5.00, $3=1, $4='picture/fries.jpg'
-- Example 3: $1='Iced Cola', $2=2.50, $3=3, $4='picture/cola.webp'
-- Example 4: $1='Orange Juice', $2=4.00, $3=3, $4='picture/orange.jpg'

-- ============================================
-- CUSTOMER SIDE QUERIES
-- Using $1, $2, $3 as placeholders for variables
-- ============================================

-- Function 1: Customer Menu View
-- UI: Customer - After entering table number, view menu
-- Description: Get all menu items with categories
-- Parameters: None (shows all available items)
SELECT 
    m.item_id, 
    m.item_name, 
    m.price, 
    c.category_name,
    m.image_url
FROM menu_items m
JOIN categories c ON m.category_id = c.category_id
WHERE m.is_available = TRUE
ORDER BY c.category_name, m.item_name;

-- Function 2: Customer Confirm Order
-- UI: Customer - Click "Confirm Order" button
-- Description: Place new order or add to existing order

-- Step 2a: Check for existing order
-- Parameters: $1 = table_number (e.g., 5)
SELECT order_id 
FROM orders 
WHERE table_number = $1 
  AND status != 'Fulfilled' 
ORDER BY order_time DESC 
LIMIT 1;

-- Step 2b: If no existing order, create new one
-- Parameters: $1 = table_number, $2 = total_amount, $3 = status
INSERT INTO orders (table_number, total_amount, status) 
VALUES ($1, $2, $3)
RETURNING order_id;
-- Example: $1=5, $2=29.00, $3='New'

-- Step 2c: Insert order items
-- Parameters: $1 = order_id, $2 = item_id, $3 = quantity, $4 = item_price
INSERT INTO order_items (order_id, item_id, quantity, item_price) 
VALUES ($1, $2, $3, $4);
-- Example call 1: $1=1, $2=1, $3=2, $4=12.00 (2x Cheese Burger)
-- Example call 2: $1=1, $2=2, $3=1, $4=5.00 (1x French Fries)

-- Function 3: Customer Order Status/Order Tracker
-- UI: Customer - "Order Tracker" section
-- Description: View order history for current table
-- Parameters: $1 = table_number (e.g., 5)
SELECT 
    o.order_id,
    o.table_number,
    o.total_amount,
    o.status,
    o.order_time,
    m.item_name,
    oi.quantity,
    oi.item_price
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN menu_items m ON oi.item_id = m.item_id
WHERE o.table_number = $1
ORDER BY o.order_time DESC;
-- Example: $1=5 returns all orders for Table 5

-- ============================================
-- KITCHEN STAFF SIDE QUERIES
-- ============================================

-- Function 4: Kitchen Staff Login
-- UI: Login page - Click "Kitchen Staff Login"
-- Description: Validate kitchen staff credentials
-- Parameters: $1 = username, $2 = password, $3 = role
SELECT user_id, username, role 
FROM users 
WHERE username = $1 
  AND password = $2
  AND role = $3;
-- Example: $1='kitchen', $2='kitchen123', $3='kitchen'

-- Function 5: Kitchen View Active Orders
-- UI: Kitchen - Order queue dashboard
-- Description: Get all orders that need to be prepared
-- Parameters: None (shows all unfulfilled orders)
SELECT 
    o.order_id,
    CONCAT('Table ', o.table_number) AS table_id,
    o.total_amount,
    o.status,
    o.order_time,
    json_agg(
        json_build_object(
            'name', m.item_name,
            'quantity', oi.quantity,
            'price', oi.item_price
        )
    ) AS items
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN menu_items m ON oi.item_id = m.item_id
WHERE o.status != 'Fulfilled'
GROUP BY o.order_id
ORDER BY o.order_time ASC;

-- Function 6: Kitchen Update Order Status
-- UI: Kitchen - Click "Start Preparation" or "Ready for Pickup"
-- Description: Update order status
-- Parameters: $1 = new_status, $2 = order_id

-- Update to "In Progress"
UPDATE orders 
SET status = $1, 
    updated_at = CURRENT_TIMESTAMP 
WHERE order_id = $2;
-- Example: $1='In Progress', $2=1

-- Update to "Fulfilled"
UPDATE orders 
SET status = $1, 
    updated_at = CURRENT_TIMESTAMP 
WHERE order_id = $2;
-- Example: $1='Fulfilled', $2=1

-- ============================================
-- ADMIN SIDE QUERIES
-- ============================================

-- Function 7: Admin Login
-- UI: Login page - Click "Admin Login"
-- Description: Validate admin credentials
-- Parameters: $1 = username, $2 = password, $3 = role
SELECT user_id, username, role 
FROM users 
WHERE username = $1 
  AND password = $2
  AND role = $3;
-- Example: $1='admin', $2='admin123', $3='admin'

-- Function 8: Admin View Menu Items
-- UI: Admin - Menu list display
-- Description: Get all menu items for management
-- Parameters: None
SELECT 
    m.item_id, 
    m.item_name, 
    m.price,
    c.category_name,
    m.image_url
FROM menu_items m
JOIN categories c ON m.category_id = c.category_id
ORDER BY m.item_name;

-- Function 9: Admin Calculate Revenue
-- UI: Admin - "Revenue: $XXX.XX" display
-- Description: Calculate total revenue from all orders
-- Parameters: None
SELECT SUM(total_amount) AS total_revenue 
FROM orders;

-- Function 10: Admin Add New Menu Item
-- UI: Admin - "Add New Item" form
-- Description: Add new menu item to database

-- Step 10a: Get category ID from category name
-- Parameters: $1 = category_name
SELECT category_id 
FROM categories 
WHERE category_name = $1;
-- Example: $1='Main Dishes' returns category_id=2

-- Step 10b: Insert new menu item
-- Parameters: $1 = item_name, $2 = price, $3 = category_id, $4 = image_url
INSERT INTO menu_items (item_name, price, category_id, image_url)
VALUES ($1, $2, $3, $4)
RETURNING item_id, item_name, price;
-- Example: $1='Grilled Chicken', $2=15.00, $3=2, $4=''

-- Function 11: Admin Delete Menu Item
-- UI: Admin - Click "Delete" button next to menu item
-- Description: Remove item from menu
-- Parameters: $1 = item_id
DELETE FROM menu_items 
WHERE item_id = $1;
-- Example: $1=5 deletes item with ID 5

-- Function 12: Admin View All Orders (Sales Report)
-- UI: Admin - Sales table on right side
-- Description: Get all orders for revenue tracking
-- Parameters: None
SELECT 
    o.order_id,
    CONCAT('Table ', o.table_number) AS table,
    o.total_amount,
    o.status,
    o.order_time
FROM orders o
ORDER BY o.order_time DESC;

-- Function 13: Admin Reset All Sales Data
-- UI: Admin - Click "Reset Sales" button
-- Description: Delete all orders (CASCADE removes order_items automatically)
-- Parameters: None
DELETE FROM orders;

-- ============================================
-- EXAMPLES WITH ACTUAL VALUES
-- (For Presentation Demonstration)
-- ============================================

-- Example 1: Customer at Table 5 views menu
-- (No parameters needed)

-- Example 2: Customer at Table 5 places order for $29.00
-- Check existing order:
SELECT order_id FROM orders WHERE table_number = 5 AND status != 'Fulfilled' LIMIT 1;
-- Create new order:
INSERT INTO orders (table_number, total_amount, status) VALUES (5, 29.00, 'New') RETURNING order_id;
-- Add items:
INSERT INTO order_items (order_id, item_id, quantity, item_price) VALUES (1, 1, 2, 12.00);
INSERT INTO order_items (order_id, item_id, quantity, item_price) VALUES (1, 2, 1, 5.00);

-- Example 3: Customer at Table 5 tracks their order
SELECT o.order_id, o.status, m.item_name, oi.quantity
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN menu_items m ON oi.item_id = m.item_id
WHERE o.table_number = 5;

-- Example 4: Kitchen staff logs in
SELECT user_id, username, role FROM users 
WHERE username = 'kitchen' AND password = 'kitchen123' AND role = 'kitchen';

-- Example 5: Kitchen updates order 1 to "In Progress"
UPDATE orders SET status = 'In Progress', updated_at = CURRENT_TIMESTAMP WHERE order_id = 1;

-- Example 6: Admin adds new item "Grilled Chicken"
SELECT category_id FROM categories WHERE category_name = 'Main Dishes';
INSERT INTO menu_items (item_name, price, category_id, image_url) 
VALUES ('Grilled Chicken', 15.00, 2, '') RETURNING item_id, item_name, price;


-- Total Tables: 5 (users, categories, menu_items, orders, order_items)
-- Total Functions: 13
-- Customer Functions: 3
-- Kitchen Functions: 3
-- Admin Functions: 7
-- All queries use parameterized variables ($1, $2, $3, etc.)