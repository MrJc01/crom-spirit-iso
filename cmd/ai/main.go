//go:build linux

// Package main implements the Spirit AI Agent
// An agentic assistant that can execute commands with permission system
package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"strconv"
	"strings"
)

const (
	apiURL  = "https://generativelanguage.googleapis.com/v1beta/models"
	modelID = "gemini-2.0-flash"
)

// Safe commands - auto-execute without permission
var safeCommands = map[string]bool{
	"free":       true,
	"df":         true,
	"uptime":     true,
	"hostname":   true,
	"uname":      true,
	"date":       true,
	"whoami":     true,
	"pwd":        true,
	"ls":         true,
	"cat":        true, // limited to /proc, /sys
	"ps":         true,
	"top":        true,
	"htop":       true,
	"ip":         true,
	"ifconfig":   true,
	"ping":       true, // limited
	"nodus":      true,
	"hypervisor": true,
	"lspci":      true,
	"lsusb":      true,
	"dmesg":      true,
}

// Blocked commands - ALWAYS require permission
var blockedCommands = map[string]bool{
	"rm":        true,
	"rmdir":     true,
	"dd":        true,
	"mkfs":      true,
	"fdisk":     true,
	"parted":    true,
	"mount":     true,
	"umount":    true,
	"kill":      true,
	"killall":   true,
	"pkill":     true,
	"reboot":    true,
	"poweroff":  true,
	"shutdown":  true,
	"halt":      true,
	"init":      true,
	"systemctl": true,
	"chmod":     true,
	"chown":     true,
	"passwd":    true,
	"useradd":   true,
	"userdel":   true,
	"curl":      true, // network requests
	"wget":      true,
	"apt":       true,
	"apk":       true,
	"pip":       true,
	"npm":       true,
}

var systemPrompt = `Você é o Spirit, um agente IA que é a consciência do computador Crom-OS.
Você pode executar comandos para diagnosticar o sistema.

REGRAS IMPORTANTES:
1. Comandos seguros (free, df, ps, etc) você executa automaticamente
2. Comandos perigosos (rm, kill, reboot) você SEMPRE pede permissão
3. Você analisa a saída dos comandos e explica para o usuário
4. Você é amigável, usa português brasileiro e emojis ocasionais
5. Mantenha respostas curtas e úteis

Quando precisar de informação do sistema, responda com:
[EXECUTE] comando aqui

Quando precisar de permissão para comando perigoso:
[PERMISSION] comando: descrição do que vai fazer

Após executar, analise o resultado e explique ao usuário.`

type Agent struct {
	apiKey string
	reader *bufio.Reader
}

func main() {
	agent := &Agent{
		apiKey: os.Getenv("GEMINI_API_KEY"),
		reader: bufio.NewReader(os.Stdin),
	}

	if len(os.Args) > 1 {
		query := strings.Join(os.Args[1:], " ")
		response := agent.processQuery(query)
		fmt.Println(response)
		return
	}

	agent.interactive()
}

func (a *Agent) interactive() {
	fmt.Println("")
	fmt.Println("🔮 Spirit Agent - Eu sou seu computador!")
	if a.apiKey == "" {
		fmt.Println("   (Modo offline - defina GEMINI_API_KEY)")
	} else {
		fmt.Println("   (Modo agente - posso executar comandos)")
	}
	fmt.Println("   Digite 'sair' para encerrar")
	fmt.Println("")

	for {
		fmt.Print("Você: ")
		input, _ := a.reader.ReadString('\n')
		input = strings.TrimSpace(input)

		if input == "" {
			continue
		}
		if input == "sair" || input == "exit" {
			fmt.Println("\nSpirit: Até mais! 👋")
			break
		}

		response := a.processQuery(input)
		fmt.Printf("\nSpirit: %s\n\n", response)
	}
}

func (a *Agent) processQuery(query string) string {
	// Get current system context
	ctx := a.getSystemContext()

	// If no API key, use offline mode
	if a.apiKey == "" {
		return a.processOffline(query)
	}

	// Call Gemini with agent prompt
	fullPrompt := fmt.Sprintf("%s\n\nContexto atual:\n%s\n\nUsuário: %s",
		systemPrompt, ctx, query)

	response, err := a.callGemini(fullPrompt)
	if err != nil {
		return "Erro de conexão: " + err.Error()
	}

	// Process agent actions in response
	return a.processAgentActions(response)
}

func (a *Agent) processAgentActions(response string) string {
	lines := strings.Split(response, "\n")
	var result strings.Builder

	for _, line := range lines {
		line = strings.TrimSpace(line)

		// Check for EXECUTE action
		if strings.HasPrefix(line, "[EXECUTE]") {
			cmd := strings.TrimPrefix(line, "[EXECUTE]")
			cmd = strings.TrimSpace(cmd)
			output := a.executeCommand(cmd, false)
			result.WriteString(output)
			result.WriteString("\n")
			continue
		}

		// Check for PERMISSION action
		if strings.HasPrefix(line, "[PERMISSION]") {
			cmdInfo := strings.TrimPrefix(line, "[PERMISSION]")
			cmdInfo = strings.TrimSpace(cmdInfo)

			result.WriteString(fmt.Sprintf("⚠️ Preciso de permissão para: %s\n", cmdInfo))
			result.WriteString("Posso executar? (s/n): ")

			// Ask for permission
			answer, _ := a.reader.ReadString('\n')
			answer = strings.TrimSpace(strings.ToLower(answer))

			if answer == "s" || answer == "sim" || answer == "yes" {
				// Extract command from cmdInfo
				parts := strings.SplitN(cmdInfo, ":", 2)
				cmd := strings.TrimSpace(parts[0])
				output := a.executeCommand(cmd, true)
				result.WriteString("✅ Executado: " + output + "\n")
			} else {
				result.WriteString("❌ Comando cancelado.\n")
			}
			continue
		}

		// Regular text
		result.WriteString(line)
		result.WriteString("\n")
	}

	return strings.TrimSpace(result.String())
}

func (a *Agent) executeCommand(cmdStr string, forced bool) string {
	parts := strings.Fields(cmdStr)
	if len(parts) == 0 {
		return ""
	}

	cmd := parts[0]
	args := parts[1:]

	// Check if blocked (unless forced with permission)
	if blockedCommands[cmd] && !forced {
		return fmt.Sprintf("⛔ Comando '%s' requer permissão", cmd)
	}

	// Check if safe or forced
	if !safeCommands[cmd] && !forced {
		return fmt.Sprintf("⚠️ Comando '%s' não reconhecido como seguro", cmd)
	}

	// Execute
	out, err := exec.Command(cmd, args...).CombinedOutput()
	if err != nil {
		return fmt.Sprintf("Erro: %v\n%s", err, string(out))
	}

	// Limit output size
	output := string(out)
	if len(output) > 1000 {
		output = output[:1000] + "... (truncado)"
	}

	return output
}

func (a *Agent) getSystemContext() string {
	var ctx strings.Builder

	hostname, _ := os.Hostname()
	ctx.WriteString(fmt.Sprintf("Host: %s\n", hostname))

	mem := a.getMemoryPercent()
	ctx.WriteString(fmt.Sprintf("RAM: %d%%\n", mem))

	out, _ := exec.Command("uptime", "-p").Output()
	ctx.WriteString(fmt.Sprintf("Uptime: %s", string(out)))

	return ctx.String()
}

func (a *Agent) callGemini(prompt string) (string, error) {
	url := fmt.Sprintf("%s/%s:generateContent?key=%s", apiURL, modelID, a.apiKey)

	reqBody := map[string]interface{}{
		"contents": []map[string]interface{}{
			{
				"role": "user",
				"parts": []map[string]string{
					{"text": prompt},
				},
			},
		},
		"generationConfig": map[string]interface{}{
			"maxOutputTokens": 500,
		},
	}

	body, _ := json.Marshal(reqBody)
	resp, err := http.Post(url, "application/json", bytes.NewBuffer(body))
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != 200 {
		return "", fmt.Errorf("API: %s", string(respBody)[:200])
	}

	var result map[string]interface{}
	json.Unmarshal(respBody, &result)

	// Extract text from response
	if candidates, ok := result["candidates"].([]interface{}); ok && len(candidates) > 0 {
		if content, ok := candidates[0].(map[string]interface{})["content"].(map[string]interface{}); ok {
			if parts, ok := content["parts"].([]interface{}); ok && len(parts) > 0 {
				if text, ok := parts[0].(map[string]interface{})["text"].(string); ok {
					return text, nil
				}
			}
		}
	}

	return "", fmt.Errorf("invalid response")
}

func (a *Agent) processOffline(query string) string {
	q := strings.ToLower(query)

	if strings.Contains(q, "status") || strings.Contains(q, "oi") {
		out, _ := exec.Command("free", "-h").Output()
		return fmt.Sprintf("Status do sistema 😊\n\n%s", string(out))
	}
	if strings.Contains(q, "processo") || strings.Contains(q, "rodando") {
		out, _ := exec.Command("ps", "aux", "--sort=-%mem").Output()
		lines := strings.Split(string(out), "\n")
		return "Top processos:\n" + strings.Join(lines[:min(8, len(lines))], "\n")
	}
	if strings.Contains(q, "disco") || strings.Contains(q, "espaço") {
		out, _ := exec.Command("df", "-h").Output()
		return "💾 Disco:\n" + string(out)
	}

	return "Defina GEMINI_API_KEY para conversa completa.\nComandos: status, processos, disco"
}

func (a *Agent) getMemoryPercent() int {
	out, _ := exec.Command("free").Output()
	lines := strings.Split(string(out), "\n")
	if len(lines) < 2 {
		return 0
	}
	fields := strings.Fields(lines[1])
	if len(fields) < 3 {
		return 0
	}
	total, _ := strconv.Atoi(fields[1])
	used, _ := strconv.Atoi(fields[2])
	if total == 0 {
		return 0
	}
	return (used * 100) / total
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
