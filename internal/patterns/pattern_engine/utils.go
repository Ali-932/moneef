package pattern_engine

import "fmt"

type MetadataExtractor struct {
	metadata map[string]interface{}
	errors   []error
}

func NewMetadataExtractor(metadata interface{}) (*MetadataExtractor, error) {
	m, ok := metadata.(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("invalid metadata type")
	}
	return &MetadataExtractor{metadata: m, errors: []error{}}, nil
}

func (e *MetadataExtractor) GetFloat64(key string) float64 {
	val, ok := e.metadata[key].(float64)
	if !ok {
		e.errors = append(e.errors, fmt.Errorf("invalid or missing key: %s", key))
		return 0
	}
	return val
}

func (e *MetadataExtractor) HasErrors() bool {
	return len(e.errors) > 0
}

func (e *MetadataExtractor) Error() error {
	if len(e.errors) == 0 {
		return nil
	}
	return fmt.Errorf("metadata extraction errors: %v", e.errors)
}
