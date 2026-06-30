package handlers

import (
	"net/http"

	"emoney-2fa/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type ProductHandler struct {
	db *gorm.DB
}

func NewProductHandler(db *gorm.DB) *ProductHandler {
	return &ProductHandler{db: db}
}

func (h *ProductHandler) GetProducts(c *gin.Context) {
	var products []models.Product
	if err := h.db.Where("is_active = ?", true).Find(&products).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"message": "Gagal mengambil data produk",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    products,
	})
}

func (h *ProductHandler) GetProductByID(c *gin.Context) {
	id := c.Param("id")

	var product models.Product
	if err := h.db.First(&product, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"success": false,
			"message": "Produk tidak ditemukan",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    product,
	})
}
