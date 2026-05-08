package service

import (
	"errors"
	"moneef/internal/categories/dto"
	"moneef/internal/categories/repository"
	"moneef/internal/db"
	"moneef/internal/models"
)

var ErrDuplicateName = errors.New("category name already exists")

func ListCategories(profileID uint) ([]models.Category, error) {
	return repository.ListCategories(profileID)
}

func CreateCategory(profileID uint, req dto.CreateCategoryRequest) (*models.Category, error) {
	pid := &profileID
	category := &models.Category{
		ProfileID: pid,
		Name:      req.Name,
		Type:      &req.Type,
		Icon:      req.Icon,
		Color:     req.Color,
	}
	exists, err := repository.ExistsByName(profileID, req.Name)
	if err != nil {
		return nil, err
	}
	if exists {
		return nil, ErrDuplicateName
	}
	if err := repository.CreateCategory(category); err != nil {
		return nil, err
	}
	return category, nil
}

func UpdateCategory(id uint, profileID uint, req dto.UpdateCategoryRequest) error {
	updates := make(map[string]interface{})
	if req.Name != "" {
		updates["name"] = req.Name
	}
	if req.Icon != "" {
		updates["icon"] = req.Icon
	}
	if req.Color != "" {
		updates["color"] = req.Color
	}
	if len(updates) == 0 {
		return nil
	}
	return repository.UpdateCategory(db.DB, id, profileID, updates)
}
