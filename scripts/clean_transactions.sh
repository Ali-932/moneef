#!/bin/bash

# Script to clean all transaction data from the database
# WARNING: This will delete ALL transactions and recurrence templates!

echo "⚠️  WARNING: This will delete ALL transaction data!"
echo "This includes:"
echo "- All transactions"
echo "- All recurrence templates"
echo "- Transaction-category associations"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Operation cancelled"
    exit 0
fi

echo "🗑️  Cleaning transaction data..."

# Check if we're in the right directory
if [ ! -f "go.mod" ]; then
    echo "❌ Error: Please run this script from the project root directory"
    exit 1
fi

# Create a simple Go script to clean the data
cat > tmp_rovodev_clean.go << 'EOF'
package main

import (
	"log"
	"moneef/internal/db"
	"moneef/internal/models"
)

func main() {
	database, err := db.Connect()
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	// Delete all transactions (this will also clean up associations)
	if err := database.Unscoped().Delete(&models.Transaction{}, "1=1").Error; err != nil {
		log.Fatalf("Failed to delete transactions: %v", err)
	}

	// Delete all recurrence templates
	if err := database.Unscoped().Delete(&models.RecurrenceTemplate{}, "1=1").Error; err != nil {
		log.Fatalf("Failed to delete recurrence templates: %v", err)
	}

	log.Println("✅ All transaction data cleaned successfully!")
}
EOF

# Run the cleanup
go run tmp_rovodev_clean.go

# Remove the temporary file
rm tmp_rovodev_clean.go

echo "🧹 Cleanup completed!"