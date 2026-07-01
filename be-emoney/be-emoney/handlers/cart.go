package handlers

import (
	"net/http"

	"emoney-2fa/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type CartHandler struct {
	db *gorm.DB
}

func NewCartHandler(db *gorm.DB) *CartHandler {
	return &CartHandler{db: db}
}

func (h *CartHandler) GetCart(c *gin.Context) {
	userID := c.GetUint("user_id")

	var cartItems []models.Cart
	if err := h.db.Where("user_id = ?", userID).Preload("Product").Find(&cartItems).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"message": "Gagal mengambil data cart",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    cartItems,
	})
}

func (h *CartHandler) AddToCart(c *gin.Context) {
	userID := c.GetUint("user_id")

	var req struct {
		ProductID uint `json:"product_id" binding:"required"`
		Quantity  int  `json:"quantity" binding:"required,min=1"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "product_id dan quantity diperlukan",
		})
		return
	}

	// Cek apakah produk ada
	var product models.Product
	if err := h.db.First(&product, req.ProductID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"success": false,
			"message": "Produk tidak ditemukan",
		})
		return
	}

	// Cek stok
	if product.Stock < req.Quantity {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Stok tidak cukup",
		})
		return
	}

	// Cek apakah sudah ada di cart
	var existingCart models.Cart
	result := h.db.Where("user_id = ? AND product_id = ?", userID, req.ProductID).First(&existingCart)

	if result.Error == gorm.ErrRecordNotFound {
		// Tambah baru
		cart := models.Cart{
			UserID:    userID,
			ProductID: req.ProductID,
			Quantity:  req.Quantity,
		}
		if err := h.db.Create(&cart).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"success": false,
				"message": "Gagal menambahkan ke cart",
			})
			return
		}
	} else if result.Error == nil {
		// Update quantity
		existingCart.Quantity += req.Quantity
		if err := h.db.Save(&existingCart).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"success": false,
				"message": "Gagal update cart",
			})
			return
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Produk ditambahkan ke cart",
	})
}

func (h *CartHandler) RemoveFromCart(c *gin.Context) {
	userID := c.GetUint("user_id")
	cartID := c.Param("id")

	if err := h.db.Where("id = ? AND user_id = ?", cartID, userID).Delete(&models.Cart{}).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"message": "Gagal menghapus dari cart",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Produk dihapus dari cart",
	})
}

func (h *CartHandler) ClearCart(c *gin.Context) {
	userID := c.GetUint("user_id")

	if err := h.db.Where("user_id = ?", userID).Delete(&models.Cart{}).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"message": "Gagal mengosongkan cart",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Cart dikosongkan",
	})
}
