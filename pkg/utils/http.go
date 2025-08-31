package utils

import (
	"io"
	"net/http"
	"time"
)

func MakeRequestWithRetry(client *http.Client, method, url string, body io.Reader) (*http.Response, error) {
	for i := 0; i < 3; i++ {
		req, err := http.NewRequest(method, url, body)
		if err != nil {
			return nil, err
		}

		if resp, err := client.Do(req); err == nil {
			return resp, nil
		} else if i == 2 {
			return nil, err
		}
		time.Sleep(2 * time.Second)
	}
	return nil, nil
}
