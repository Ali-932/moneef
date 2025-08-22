# How to Create Models

## Basic Model Structure
```go
package models

import (
    "gorm.io/gorm"
    "time"
)

type YourModel struct {
    gorm.Model
    Name        string    `gorm:"type:varchar(255);not null"`
    Email       string    `gorm:"type:varchar(255);unique;not null"`
    Age         int       `gorm:"default:0"`
    IsActive    bool      `gorm:"default:true"`
    CreatedAt   time.Time `gorm:"autoCreateTime"`
    UpdatedAt   time.Time `gorm:"autoUpdateTime"`
    DeletedAt   gorm.DeletedAt `gorm:"index"`
    UserID      uint      `gorm:"not null;index"`
}
```

## GORM Field Tags
- `gorm:"primaryKey"` - Primary key
- `gorm:"autoIncrement"` - Auto increment
- `gorm:"unique"` - Unique constraint
- `gorm:"not null"` - Not null constraint
- `gorm:"index"` - Create index
- `gorm:"type:varchar(255)"` - Specify column type
- `gorm:"default:value"` - Default value
- `gorm:"size:255"` - Column size
- `gorm:"column:custom_name"` - Custom column name
- `gorm:"foreignKey:UserID"` - Foreign key
- `gorm:"references:ID"` - References field
- `gorm:"constraint:OnUpdate:CASCADE,OnDelete:SET NULL"` - Constraints
- `gorm:"autoCreateTime"` - Auto create timestamp
- `gorm:"autoUpdateTime"` - Auto update timestamp