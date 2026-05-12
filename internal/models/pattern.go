package models

import "time"

type Pattern struct {
	ID          uint        `gorm:"primaryKey" json:"id"`
	CreatedAt   time.Time   `json:"created_at"`
	UpdatedAt   time.Time   `json:"updated_at"`
	Name        string      `gorm:"not null; type:varchar(255);" json:"name"`
	Description string      `gorm:"type:text;" json:"description"`
	Metadata    interface{} `gorm:"type:json;" json:"metadata,omitempty"`
	Icon        string      `gorm:"not null; type:varchar(255);" json:"icon"`
	Color       string      `gorm:"not null; type:varchar(255);" json:"color"`
	Type        string      `gorm:"not null; type:varchar(255);" json:"pattern_type"`
	FinalScore  float64     `gorm:"not null; type:float;" json:"final_score"`
	ProfileID   *uint       `json:"profile_id,omitempty"`
}
