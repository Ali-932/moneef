//go:build !android

package cmd

import (
	"os"
	"os/exec"

	"github.com/spf13/cobra"
)

var runCmd = &cobra.Command{
	Use:   "run",
	Short: "Start the API server",
	Long:  `Start the moneef API server by running the API main file.`,
	Run: func(cmd *cobra.Command, args []string) {
		apiCmd := exec.Command("go", "run", "./cmd/api/")
		apiCmd.Stdout = os.Stdout
		apiCmd.Stderr = os.Stderr
		apiCmd.Stdin = os.Stdin
		
		if err := apiCmd.Run(); err != nil {
			os.Exit(1)
		}
	},
}

func init() {
	rootCmd.AddCommand(runCmd)
}