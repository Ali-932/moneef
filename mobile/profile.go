//go:build android || smoke

package mobile

import (
	"encoding/json"
	"fmt"

	userdto "moneef/internal/users/dto"
	usersvc "moneef/internal/users/service"
)

// resolveUserID looks up the User ID associated with the active profile.
// Settings endpoints are keyed by user, not profile, so this hop is needed.
func resolveUserID(pid uint) (uint, error) {
	profile, err := usersvc.GetProfile(pid)
	if err != nil {
		return 0, fmt.Errorf("resolve user id: %w", err)
	}
	return profile.UserID, nil
}

func GetProfile() ([]byte, error) {
	pid, err := getProfileID()
	if err != nil {
		return nil, err
	}
	profile, err := usersvc.GetProfile(pid)
	if err != nil {
		return nil, err
	}
	user, err := usersvc.GetUserByID(profile.UserID)
	if err != nil {
		return nil, err
	}
	resp := userdto.ProfileResponse{
		ID:        profile.ID,
		FirstName: profile.FirstName,
		LastName:  profile.LastName,
		Email:     user.Email,
		Birthday:  user.Birthday,
	}
	return json.Marshal(resp)
}

func UpdateProfile(payload []byte) error {
	pid, err := getProfileID()
	if err != nil {
		return err
	}
	var req userdto.UpdateProfileRequest
	if err := json.Unmarshal(payload, &req); err != nil {
		return fmt.Errorf("%w: %v", ErrInvalidPayload, err)
	}
	return usersvc.UpdateProfile(pid, req)
}

func GetSettings() ([]byte, error) {
	pid, err := getProfileID()
	if err != nil {
		return nil, err
	}
	uid, err := resolveUserID(pid)
	if err != nil {
		return nil, err
	}
	settings, err := usersvc.GetSettings(uid)
	if err != nil {
		return nil, err
	}
	resp := userdto.SettingsResponse{
		CurrencyCode:          settings.CurrencyCode,
		Language:              settings.Language,
		IsNotificationEnabled: settings.IsNotificationEnabled,
		IsDarkMode:            settings.IsDarkMode,
		ExchangeRateApiKey:    settings.ExchangeRateApiKey,
	}
	return json.Marshal(resp)
}

func UpdateSettings(payload []byte) error {
	pid, err := getProfileID()
	if err != nil {
		return err
	}
	uid, err := resolveUserID(pid)
	if err != nil {
		return err
	}
	var req userdto.UpdateSettingsRequest
	if err := json.Unmarshal(payload, &req); err != nil {
		return fmt.Errorf("%w: %v", ErrInvalidPayload, err)
	}
	return usersvc.UpdateSettings(uid, req)
}
