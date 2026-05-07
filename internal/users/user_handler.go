package users

import (
	"encoding/json"
	"github.com/go-playground/validator/v10"
	"gorm.io/gorm"
	"moneef/internal/models"
	"moneef/internal/users/dto"
	"moneef/internal/users/service"
	"moneef/pkg/utils"
	"net/http"
)

func RegisterUserHandler(w http.ResponseWriter, r *http.Request) {
	var req dto.RegisterRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, "Invalid Input")
		return
	}
	validate := validator.New()
	if err := validate.Struct(req); err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, err.Error())
		return
	}
	emailExist, err := service.CheckEmailExist(req.Email)
	if err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, err.Error())
		return
	}
	if emailExist {
		utils.WriteJsonError(w, http.StatusConflict, "Email already exists")
		return
	}
	hashedPassword, err := utils.HashPassword(req.Password)
	if err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, "Could not hash password")
		return
	}
	err = service.CreateUserService(&models.User{
		Model:    gorm.Model{},
		Email:    req.Email,
		Password: string(hashedPassword),
		Birthday: req.Birthday,
	})
	if err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, "Could not create user")
	}
}
