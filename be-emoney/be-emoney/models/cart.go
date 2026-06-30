package models

import "gorm.io/gorm"

type Cart struct {
	gorm.Model
	UserID    uint    `gorm:"not null;index" json:"user_id"`
	ProductID uint    `gorm:"not null;index" json:"product_id"`
	Quantity  int     `gorm:"not null;default:1" json:"quantity"`
	Product   Product `gorm:"foreignKey:ProductID" json:"product,omitempty"`
	User      User    `gorm:"foreignKey:UserID" json:"-"`
}
