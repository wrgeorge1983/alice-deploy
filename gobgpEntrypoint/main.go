package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"strconv"

	// import other packages necessary for handling your config file
	yaml "gopkg.in/yaml.v2"
)

// example config file
// global:
//   config:
//     as: 65000
//     router-id: 10.0.0.1
//     port: 179

// neighbors:
//   - config:
//       neighbor-address: 10.0.1.100
//       peer-as: 65000

type GlobalConfig struct {
	ASN      int    `yaml:"as"`
	RouterID string `yaml:"router-id"`
	Port     int    `yaml:"port"`
}

type NeighborConfig struct {
	NeighborAddress string                 `yaml:"neighbor-address"`
	PeerAs          int                    `yaml:"peer-as"`
	Extras          map[string]interface{} `yaml:",inline"`
}

type GoBgpConfig struct {
	Global struct {
		Config GlobalConfig `yaml:"config"`
	} `yaml:"global"`
	Neighbors []struct {
		Config NeighborConfig         `yaml:"config"`
		Extras map[string]interface{} `yaml:",inline"`
	} `yaml:"neighbors"`
	Extras map[string]interface{} `yaml:",inline"`
}

func main() {
	// Read environment variables

	inputConfigFile, exists := os.LookupEnv("INPUT_CONFIG_FILE")
	if !exists {
		log.Fatalf("error: INPUT_CONFIG_FILE not set")
	}

	outputConfigFile, exists := os.LookupEnv("OUTPUT_CONFIG_FILE")
	if !exists {
		log.Fatalf("error: OUTPUT_CONFIG_FILE not set")
	}

	goBgpdPath, exists := os.LookupEnv("GOBGPD_PATH")
	if !exists {
		log.Fatalf("error: GOBGPD_PATH not set")
	}

	maxPeers := 3

	data, err := os.ReadFile(inputConfigFile)
	if err != nil {
		log.Fatalf("error: %v", err)
	}

	var config GoBgpConfig

	err = yaml.Unmarshal(data, &config)
	if err != nil {
		log.Fatalf("error: %v", err)
	}

	localAs, err := strconv.Atoi(os.Getenv("LOCAL_AS"))
	if err == nil {
		config.Global.Config.ASN = localAs
	}
	if config.Global.Config.ASN == 0 {
		log.Fatalf("error: Local AS not set")
	}

	routerID := os.Getenv("ROUTER_ID")
	if routerID != "" {
		config.Global.Config.RouterID = routerID
	}
	if config.Global.Config.RouterID == "" {
		log.Fatalf("error: Router ID not set")
	}

	for i := 1; i <= maxPeers; i++ {
		peerAddress := os.Getenv(fmt.Sprintf("PEER%d_ADDRESS", i))
		if peerAddress == "" {
			break
		}
		peerAs, err := strconv.Atoi(os.Getenv(fmt.Sprintf("PEER%d_AS", i)))
		if err != nil {
			log.Fatalf("error: %v", err)
		}
		log.Printf("Adding Peer %d: %s, AS %d\n", i, peerAddress, peerAs)
		neigh := struct {
			Config NeighborConfig         `yaml:"config"`
			Extras map[string]interface{} `yaml:",inline"`
		}{
			NeighborConfig{
				NeighborAddress: peerAddress,
				PeerAs:          peerAs,
			},
			map[string]interface{}{},
		}
		config.Neighbors = append(config.Neighbors, neigh)
	}

	yamlData, err := yaml.Marshal(&config)
	if err != nil {
		log.Fatalf("error: %v", err)
	}

	fmt.Println(string(yamlData))

	// Write the modified configuration back to the file
	err = os.WriteFile(outputConfigFile, yamlData, 0644)
	if err != nil {
		log.Fatalf("error: %v", err)
	}

	// Start your main application
	cmd := exec.Command(goBgpdPath, "-t", "yaml", "-f", outputConfigFile)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		log.Fatal(err)
	}
}
