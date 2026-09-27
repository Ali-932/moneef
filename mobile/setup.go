//go:build android || smoke

package mobile

import (
	"encoding/json"
	"fmt"

	userdto "moneef/internal/users/dto"
	usersvc "moneef/internal/users/service"
)

// SetupResponse is the JSON envelope returned by Setup. The Flutter side
// stores profile_id locally and supplies it to Init on subsequent launches.
type SetupResponse struct {
	ProfileID    int64  `json:"profile_id"`
	UserID       int64  `json:"user_id"`
	FirstName    string `json:"first_name"`
	LastName     string `json:"last_name"`
	CurrencyCode string `json:"currency_code"`
	Language     string `json:"language"`
}

// Setup creates the initial user + profile + settings. It can be called
// before SetProfileID; on success the returned profile_id should be cached
// by the Flutter app and passed to Init on subsequent launches. Init must
// still have been called first (the database must exist).
func Setup(payload []byte) ([]byte, error) {
	if err := requireInit(); err != nil {
		return nil, err
	}
	var req userdto.SetupRequest
	if err := json.Unmarshal(payload, &req); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrInvalidPayload, err)
	}
	profile, settings, err := usersvc.Setup(req)
	if err != nil {
		return nil, err
	}
	if err := SetProfileID(int64(profile.ID)); err != nil {
		return nil, err
	}
	resp := SetupResponse{
		ProfileID:    int64(profile.ID),
		UserID:       int64(profile.UserID),
		FirstName:    profile.FirstName,
		LastName:     profile.LastName,
		CurrencyCode: settings.CurrencyCode,
		Language:     settings.Language,
	}
	return json.Marshal(resp)
}
