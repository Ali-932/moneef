package models

import "time"

type Pattern struct {
	ID          uint        `gorm:"primaryKey" json:"id"`
	CreatedAt   time.Time   `json:"created_at"`
	UpdatedAt   time.Time   `json:"updated_at"`
	Name        string      `gorm:"not null;type:varchar(255);uniqueIndex:idx_profile_name_type" json:"name"`
	Description string      `gorm:"type:text;" json:"description"`
	Metadata    interface{} `gorm:"type:json;serializer:json" json:"metadata,omitempty"`
	Icon        string      `gorm:"not null;type:varchar(255);" json:"icon"`
	Color       string      `gorm:"not null;type:varchar(255);" json:"color"`
	Type        string      `gorm:"not null;type:varchar(50);uniqueIndex:idx_profile_name_type" json:"pattern_type"`
	FinalScore  float64     `gorm:"not null;type:float;" json:"final_score"`
	ProfileID   uint        `gorm:"not null;index;uniqueIndex:idx_profile_name_type" json:"profile_id"`
}
