package dto

type CreateCategoryRequest struct {
	Name  string `json:"name" validate:"required"`
	Type  string `json:"type" validate:"required,oneof=expense income"`
	Icon  string `json:"icon"`
	Color string `json:"color"`
}

type UpdateCategoryRequest struct {
	Name  string  `json:"name"`
	Icon  *string `json:"icon"`
	Color string  `json:"color"`
}
