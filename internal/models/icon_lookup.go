package models

import "time"

type IconLookup struct {
	ID        uint      `gorm:"primaryKey" json:"id"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	Keyword   string    `gorm:"type:varchar(255);not null;uniqueIndex"`
	Icon      string    `gorm:"type:varchar(255);not null"`
	Color     string    `gorm:"type:varchar(255);not null"`
}
