//go:build android || smoke

package mobilebridge

import (
	"encoding/json"
	"fmt"

	catdto "moneef/internal/categories/dto"
	catsvc "moneef/internal/categories/service"
	"moneef/internal/models"
)

type ListCategoriesRequest struct {
	Type   string `json:"type"`
	Custom bool   `json:"custom"`
	Used   bool   `json:"used"`
}

func ListCategories(payload []byte) ([]byte, error) {
	pid, err := getProfileID()
	if err != nil {
		return nil, err
	}
	var req ListCategoriesRequest
	if len(payload) > 0 {
		if err := json.Unmarshal(payload, &req); err != nil {
			return nil, fmt.Errorf("%w: %v", ErrInvalidPayload, err)
		}
	}
	list, err := catsvc.ListCategories(pid, req.Type, req.Custom, req.Used)
	if err != nil {
		return nil, err
	}
	if list == nil {
		list = []models.Category{}
	}
	return json.Marshal(list)
}

func CreateCategory(payload []byte) ([]byte, error) {
	pid, err := getProfileID()
	if err != nil {
		return nil, err
	}
	var req catdto.CreateCategoryRequest
	if err := json.Unmarshal(payload, &req); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrInvalidPayload, err)
	}
	cat, err := catsvc.CreateCategory(pid, req)
	if err != nil {
		return nil, err
	}
	return json.Marshal(cat)
}

func UpdateCategory(id int64, payload []byte) error {
	pid, err := getProfileID()
	if err != nil {
		return err
	}
	if id <= 0 {
		return fmt.Errorf("mobile.UpdateCategory: id must be > 0")
	}
	var req catdto.UpdateCategoryRequest
	if err := json.Unmarshal(payload, &req); err != nil {
		return fmt.Errorf("%w: %v", ErrInvalidPayload, err)
	}
	return catsvc.UpdateCategory(uint(id), pid, req)
}

func DeleteCategory(id int64) error {
	pid, err := getProfileID()
	if err != nil {
		return err
	}
	if id <= 0 {
		return fmt.Errorf("mobile.DeleteCategory: id must be > 0")
	}
	return catsvc.DeleteCategory(uint(id), pid)
}
