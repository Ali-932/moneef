# How to Create Repository

## Basic Repository Structure
```go
package repository

import (
    "goMangaObserver/internal/db"
    "goMangaObserver/internal/models"
    "gorm.io/gorm"
)

func GetYourModelByID(id uint) (*models.YourModel, error) {
    var model models.YourModel
    result := db.DB.Where("id = ?", id).First(&model)
    if result.Error != nil {
        return nil, result.Error
    }
    return &model, nil
}

func GetYourModelByField(fieldValue string) (*models.YourModel, error) {
    var model models.YourModel
    result := db.DB.Where("field_name = ?", fieldValue).First(&model)
    if result.Error != nil {
        return nil, result.Error
    }
    return &model, nil
}

func CreateYourModel(model *models.YourModel) error {
    return db.DB.Create(model).Error
}

func UpdateYourModel(model *models.YourModel) error {
    return db.DB.Save(model).Error
}

func DeleteYourModel(id uint) error {
    return db.DB.Delete(&models.YourModel{}, id).Error
}

func GetYourModelsLimited(limit int) ([]models.YourModel, error) {
    var models []models.YourModel
    result := db.DB.Limit(limit).Find(&models)
    if result.Error != nil {
        return nil, result.Error
    }
    return models, nil
}

func CreateOrUpdateYourModel(model *models.YourModel) error {
    return db.DB.Where(models.YourModel{
        UniqueField1: model.UniqueField1,
        UniqueField2: model.UniqueField2,
    }).FirstOrCreate(&model).Error
}

func SearchYourModelsByText(query string) *gorm.DB {
    return db.DB.Where("name LIKE ?", "%"+query+"%")
}

func ApplyYourFilter(query *gorm.DB, filter string) *gorm.DB {
    if filter != "" {
        return query.Where("filter_field = ?", filter)
    }
    return query
}

func ExecuteYourQuery(query *gorm.DB) ([]models.YourModel, error) {
    var results []models.YourModel
    err := query.Find(&results).Error
    return results, err
}
```

## Repository Patterns
- Single responsibility per function
- Error handling
- GORM query building
- Filtering and searching
- CRUD operations