package handlers

import (
	"net/http"

	"emoney-2fa/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type OrderHandler struct {
	db *gorm.DB
}

func NewOrderHandler(db *gorm.DB) *OrderHandler {
	return &OrderHandler{db: db}
}

type CheckoutRequest struct {
	ShippingAddress string `json:"shipping_address" binding:"required"`
	Notes           string `json:"notes"`
	PaymentMethod   string `json:"payment_method" binding:"required"`
}

// POST /v1/orders/checkout
func (h *OrderHandler) Checkout(c *gin.Context) {
	userID := c.GetUint("user_id")

	var req CheckoutRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "shipping_address dan payment_method diperlukan",
		})
		return
	}

	// Ambil cart items user
	var cartItems []models.Cart
	if err := h.db.Where("user_id = ?", userID).Preload("Product").Find(&cartItems).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"message": "Gagal mengambil data cart",
		})
		return
	}

	if len(cartItems) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Cart kosong, tidak bisa checkout",
		})
		return
	}

	// Hitung total dan buat order items
	var totalAmount float64
	var orderItems []models.OrderItem

	for _, ci := range cartItems {
		subtotal := ci.Product.Price * float64(ci.Quantity)
		totalAmount += subtotal
		orderItems = append(orderItems, models.OrderItem{
			ProductID:   ci.ProductID,
			ProductName: ci.Product.Name,
			Price:       ci.Product.Price,
			Quantity:    ci.Quantity,
			Subtotal:    subtotal,
		})
	}

	// Buat order dalam transaction
	var order models.Order
	err := h.db.Transaction(func(tx *gorm.DB) error {
		order = models.Order{
			UserID:          userID,
			TotalAmount:     totalAmount,
			Status:          "pending",
			ShippingAddress: req.ShippingAddress,
			Notes:           req.Notes,
			PaymentMethod:   req.PaymentMethod,
			Items:           orderItems,
		}
		if err := tx.Create(&order).Error; err != nil {
			return err
		}

		// Hapus cart items
		if err := tx.Where("user_id = ?", userID).Delete(&models.Cart{}).Error; err != nil {
			return err
		}

		// Kurangi stok produk
		for _, ci := range cartItems {
			if err := tx.Model(&models.Product{}).
				Where("id = ? AND stock >= ?", ci.ProductID, ci.Quantity).
				UpdateColumn("stock", gorm.Expr("stock - ?", ci.Quantity)).Error; err != nil {
				return err
			}
		}

		return nil
	})

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"message": "Gagal membuat pesanan",
		})
		return
	}

	// Reload order dengan items
	h.db.Preload("Items").First(&order, order.ID)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Pesanan berhasil dibuat",
		"data":    order,
	})
}

// GET /v1/orders
func (h *OrderHandler) GetMyOrders(c *gin.Context) {
	userID := c.GetUint("user_id")

	var orders []models.Order
	h.db.Where("user_id = ?", userID).
		Preload("Items").
		Order("created_at desc").
		Find(&orders)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    orders,
	})
}

// GET /v1/orders/:id
func (h *OrderHandler) GetOrder(c *gin.Context) {
	userID := c.GetUint("user_id")
	orderID := c.Param("id")

	var order models.Order
	if err := h.db.Where("id = ? AND user_id = ?", orderID, userID).
		Preload("Items").First(&order).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"success": false,
			"message": "Pesanan tidak ditemukan",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    order,
	})
}
