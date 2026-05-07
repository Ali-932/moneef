package pagination

import (
	"fmt"
	"math"
	"net/http"
	"net/url"
	"strconv"

	"gorm.io/gorm"
)

const (
	DefaultPage    = 1
	DefaultPerPage = 20
	MaxPerPage     = 100
)

type PaginatedResult[T any] struct {
	Count       int64  `json:"count"`
	TotalPages  int    `json:"total_pages"`
	CurrentPage int    `json:"current_page"`
	PerPage     int    `json:"per_page"`
	Next        string `json:"next"`
	Previous    string `json:"previous"`
	Results     []T    `json:"results"`
}

func parsePage(r *http.Request) int {
	p := r.URL.Query().Get("page")
	if p == "" {
		return DefaultPage
	}
	n, err := strconv.Atoi(p)
	if err != nil || n < 1 {
		return DefaultPage
	}
	return n
}

func parsePerPage(r *http.Request) int {
	pp := r.URL.Query().Get("per_page")
	if pp == "" {
		return DefaultPerPage
	}
	n, err := strconv.Atoi(pp)
	if err != nil || n < 1 {
		return DefaultPerPage
	}
	if n > MaxPerPage {
		return MaxPerPage
	}
	return n
}

func buildPageURL(r *http.Request, page int) string {
	q := r.URL.Query()
	q.Set("page", strconv.Itoa(page))
	q.Set("per_page", r.URL.Query().Get("per_page"))
	if q.Get("per_page") == "" {
		q.Set("per_page", strconv.Itoa(DefaultPerPage))
	}
	u := &url.URL{
		Scheme:   "http",
		Host:     r.Host,
		Path:     r.URL.Path,
		RawQuery: q.Encode(),
	}
	if r.TLS != nil || r.Header.Get("X-Forwarded-Proto") == "https" {
		u.Scheme = "https"
	}
	return u.String()
}

func Paginate[T any](query *gorm.DB, r *http.Request) (*PaginatedResult[T], error) {
	page := parsePage(r)
	perPage := parsePerPage(r)

	var count int64
	if err := query.Count(&count).Error; err != nil {
		return nil, fmt.Errorf("pagination count error: %w", err)
	}

	totalPages := int(math.Ceil(float64(count) / float64(perPage)))
	if totalPages == 0 {
		totalPages = 1
	}

	if page > totalPages {
		page = totalPages
	}

	offset := (page - 1) * perPage

	var results []T
	if err := query.Offset(offset).Limit(perPage).Find(&results).Error; err != nil {
		return nil, fmt.Errorf("pagination query error: %w", err)
	}

	var next, previous string
	if page < totalPages {
		next = buildPageURL(r, page+1)
	}
	if page > 1 {
		previous = buildPageURL(r, page-1)
	}

	return &PaginatedResult[T]{
		Count:       count,
		TotalPages:  totalPages,
		CurrentPage: page,
		PerPage:     perPage,
		Next:        next,
		Previous:    previous,
		Results:     results,
	}, nil
}
