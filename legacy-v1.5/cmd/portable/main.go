// MiR v0.5: app Windows con motor remoto integrado de forma opcional.
// El motor procede de la copia oficial que el propietario incorpora con MiR Creador.
// No instala servicios sin consentimiento y no modifica configuraciones existentes.
package main

import (
    "archive/zip"
    "bytes"
    "crypto/sha256"
    "io"
    _ "embed"
    "errors"
    "fmt"
    "os"
    "os/exec"
    "path/filepath"
    "strings"
    "syscall"
    "unsafe"
)

//go:embed payload.zip
var payload []byte

const version = "1.5.0"

func messageBox(title, body string, flags uintptr) uintptr {
    p := syscall.NewLazyDLL("user32.dll").NewProc("MessageBoxW")
    a, _ := syscall.UTF16PtrFromString(title)
    b, _ := syscall.UTF16PtrFromString(body)
    r, _, _ := p.Call(0, uintptr(unsafe.Pointer(b)), uintptr(unsafe.Pointer(a)), flags)
    return r
}

func sameFile(dst string, src []byte) bool {
    existing, err := os.ReadFile(dst)
    return err == nil && sha256.Sum256(existing) == sha256.Sum256(src)
}
func extract() (string, error) {
    base := os.Getenv("LOCALAPPDATA")
    if base == "" { return "", errors.New("Windows no definio LOCALAPPDATA") }
    dst := filepath.Join(base, "MiRemoto", "Runtime", "v"+version)
    zr, err := zip.NewReader(bytes.NewReader(payload), int64(len(payload)))
    if err != nil { return "", fmt.Errorf("paquete MiR invalido: %w", err) }
    for _, f := range zr.File {
        name := filepath.Clean(filepath.FromSlash(f.Name))
        if name == "." || filepath.IsAbs(name) || name == ".." || strings.HasPrefix(name, ".."+string(filepath.Separator)) { return "", errors.New("ruta invalida en los recursos") }
        target := filepath.Join(dst, name)
        if f.FileInfo().IsDir() { if err := os.MkdirAll(target, 0700); err != nil { return "", err }; continue }
        if !f.Mode().IsRegular() { return "", errors.New("recurso no regular") }
        if f.UncompressedSize64 > 6<<20 { return "", errors.New("recurso supera limite de seguridad") }
        if err := os.MkdirAll(filepath.Dir(target), 0700); err != nil { return "", err }
        rc, err := f.Open(); if err != nil { return "", err }
        content, err := io.ReadAll(io.LimitReader(rc, 6<<20)); rc.Close(); if err != nil { return "", err }
        if len(content) > 5<<20 { return "", errors.New("recurso demasiado grande") }
        if sameFile(target, content) { continue }
        tmp := target + ".nuevo"
        if err := os.WriteFile(tmp, content, 0600); err != nil { return "", err }
        if err := os.Rename(tmp, target); err != nil {
            _ = os.Remove(tmp)
            return "", fmt.Errorf("actualizando %s: %w", name, err)
        }
    }
    ps1 := filepath.Join(dst, "MiRemoto.ps1")
    if _, err := os.Stat(ps1); err != nil { return "", fmt.Errorf("falta MiRemoto.ps1: %w", err) }
    return ps1, nil
}
func main() {
    executable, err := os.Executable()
    if err != nil { messageBox("MiR", "No se encontro el ejecutable: "+err.Error(), 0x10); return }
    if err := installEngineIfBundled(); err != nil {
        messageBox("MiR - motor", "No pude preparar el motor integrado:\r\n"+err.Error(), 0x10)
        return
    }
    script, err := extract()
    if err != nil { messageBox("MiR - error", "No pude preparar los recursos locales:\r\n"+err.Error(), 0x10); return }
    if len(os.Args)>1 && os.Args[1]=="--prepare-host" { return }
    powershell := filepath.Join(os.Getenv("SystemRoot"), "System32", "WindowsPowerShell", "v1.0", "powershell.exe")
    if _, err := os.Stat(powershell); err != nil { powershell = "powershell.exe" }
    cmd := exec.Command(powershell, "-NoProfile", "-ExecutionPolicy", "Bypass", "-STA", "-WindowStyle", "Hidden", "-File", script)
    cmd.Env = append(os.Environ(), "MIREMOTO_LAUNCHER_EXE="+executable)
    cmd.Dir = filepath.Dir(script)
    cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow:true}
    if err := cmd.Start(); err != nil { messageBox("MiR", "No se pudo abrir MiR: "+err.Error(), 0x10); return }
    _ = cmd.Process.Release()
}