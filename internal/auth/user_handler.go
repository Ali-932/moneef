package auth

import (
	"encoding/json"
	"github.com/go-playground/validator/v10"
	"gorm.io/gorm"
	"moneef/internal/models"
	"moneef/pkg/utils"
	"net/http"
	"time"
)

type RegisterRequest struct {
	Email    string     `json:"email" validate:"required,email"`
	Password string     `json:"password" validate:"required"`
	Birthday *time.Time `json:"birthday"`
}

type LoginRequest struct {
	Email    string `json:"email" validate:"required,email"`
	Password string `json:"password" validate:"required"`
}

func RegisterUserHandler(w http.ResponseWriter, r *http.Request) {
	var req RegisterRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, "Invalid Input")
		return
	}
	validate := validator.New()
	if err := validate.Struct(req); err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, err.Error())
		return
	}
	emailExist, err := CheckEmailExist(req.Email)
	if err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, err.Error())
		return
	}
	if emailExist {
		utils.WriteJsonError(w, http.StatusConflict, "Email already exists")
		return
	}
	hashedPassword, err := HashPassword(req.Password)
	if err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, "Could not hash password")
		return
	}
	err = CreateUser(&models.User{
		Model:    gorm.Model{},
		Email:    req.Email,
		Password: string(hashedPassword),
		Birthday: req.Birthday,
	})
	if err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, "Could not create user")
	}
}

func LoginUserHandler(w http.ResponseWriter, r *http.Request) {
	var req LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, "Invalid Input")
		return
	}
	validate := validator.New()
	if err := validate.Struct(req); err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, err.Error())
		return
	}
	_, err := CheckUserCredentials(req.Email, req.Password)
	if err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, "Wrong email or password")
		return
	}
	token, err := GenerateJWT(req.Email)
	if err != nil {
		utils.WriteJsonError(w, http.StatusBadRequest, err.Error())
		return
	}
	_ = json.NewEncoder(w).Encode(map[string]string{"token": token})
}
