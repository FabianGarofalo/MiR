// MiR installer for the CURRENT Windows user. Does not modify RustDesk.
package main

import (
  _ "embed"
  "encoding/base64"
  "errors"
  "fmt"
  "os"
  "os/exec"
  "path/filepath"
  "strings"
  "syscall"
  "unicode/utf16"
  "unsafe"
)

//go:embed MiR_Portable.exe
var portable []byte
//go:embed MiRemoto.ico
var appIcon []byte

//go:embed MiR_Desinstalar_Base.exe
var smallUninstaller []byte

const appName = "MiR - Acceso remoto"
const regKey = `HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\MiR-Remote`

func message(title, body string, mode uintptr) uintptr {
  proc := syscall.NewLazyDLL("user32.dll").NewProc("MessageBoxW")
  t, _ := syscall.UTF16PtrFromString(title); b, _ := syscall.UTF16PtrFromString(body)
  r, _, _ := proc.Call(0, uintptr(unsafe.Pointer(b)), uintptr(unsafe.Pointer(t)), mode)
  return r
}
func destDir() (string, error) {
  base:=os.Getenv("LOCALAPPDATA")
  if base=="" { return "", errors.New("Windows no definio LOCALAPPDATA") }
  return filepath.Join(base,"Programs","MiR"),nil
}
func replaceFile(name string, content []byte) error {
  temp:=name+".nuevo"
  if err:=os.WriteFile(temp,content,0600);err!=nil{return err}
  if err:=os.Rename(temp,name);err!=nil{
    if e:=os.Remove(name);e!=nil && !os.IsNotExist(e) { return fmt.Errorf("cerra MiR antes de actualizar (%s): %w",name,e) }
    if err:=os.Rename(temp,name);err!=nil{return err}
  }
  return nil
}
func psEncoded(source string) error {
  u:=utf16.Encode([]rune(source)); bytes:=make([]byte,0,len(u)*2)
  for _,v:=range u { bytes=append(bytes,byte(v),byte(v>>8)) }
  ps:=filepath.Join(os.Getenv("SystemRoot"),"System32","WindowsPowerShell","v1.0","powershell.exe")
  cmd:=exec.Command(ps,"-NoProfile","-EncodedCommand",base64.StdEncoding.EncodeToString(bytes))
  cmd.SysProcAttr=&syscall.SysProcAttr{HideWindow:true}
  return cmd.Run()
}
func psQuote(text string) string { return "'"+strings.ReplaceAll(text,"'","''")+"'" }
func shortcuts(dir string) error {
  exe:=filepath.Join(dir,"MiR.exe")
  ico:=filepath.Join(dir,"MiRemoto.ico")
  // Desktop and user Start Menu shortcuts. Never requests Administrator.
  sc:=`$ErrorActionPreference='Stop'; $sh=New-Object -ComObject WScript.Shell; `+
    `$d=[Environment]::GetFolderPath('Desktop'); $p=[Environment]::GetFolderPath('Programs'); `+
    `foreach($path in @((Join-Path $d 'MiR.lnk'),(Join-Path $p 'MiR.lnk'))){ `+
    `$s=$sh.CreateShortcut($path);$s.TargetPath=`+psQuote(exe)+`; $s.WorkingDirectory=`+psQuote(dir)+`; `+
    `$s.IconLocation=`+psQuote(ico)+`; $s.Description='MiR - acceso remoto'; $s.Save() }`
  return psEncoded(sc)
}
func registry(dir string) error {
  uninstall:=`"`+filepath.Join(dir,"MiR_Desinstalar.exe")+`" --uninstall`
  entries:=[][3]string{
    {"DisplayName", "REG_SZ",appName},
    {"DisplayVersion", "REG_SZ","1.5.0"},
    {"Publisher", "REG_SZ","EcoEtika S.A.S."},
    {"InstallLocation", "REG_SZ",dir},
    {"UninstallString", "REG_SZ",uninstall},
    {"DisplayIcon", "REG_SZ",filepath.Join(dir,"MiRemoto.ico")},
    {"NoModify", "REG_DWORD","1"},
    {"NoRepair", "REG_DWORD","1"},
  }
  for _,item:=range entries {
    cmd:=exec.Command("reg.exe","add",regKey,"/v",item[0],"/t",item[1],"/d",item[2],"/f")
    cmd.SysProcAttr=&syscall.SysProcAttr{HideWindow:true}
    if err:=cmd.Run();err!=nil {return err}
  }
  return nil
}
func install() error {
  dir,err:=destDir();if err!=nil{return err}
  if err=os.MkdirAll(dir,0700);err!=nil{return err}
  if err=replaceFile(filepath.Join(dir,"MiR.exe"),portable);err!=nil{return err}
  if err=replaceFile(filepath.Join(dir,"MiRemoto.ico"),appIcon);err!=nil{return err}
  if err=replaceFile(filepath.Join(dir,"MiR_Desinstalar.exe"),smallUninstaller);err!=nil{return err}
  if err=installEngineIfBundled();err!=nil{return fmt.Errorf("motor integrado: %w",err)}
  if err=shortcuts(dir);err!=nil{return fmt.Errorf("accesos directos: %w",err)}
  if err=registry(dir);err!=nil{return fmt.Errorf("registro de desinstalacion: %w",err)}
  // Prepare branded MiR UI and receiver helper in the same user context.
  command:=exec.Command(filepath.Join(dir,"MiR.exe"),"--prepare-host")
  command.SysProcAttr=&syscall.SysProcAttr{HideWindow:true}
  if err:=command.Run();err!=nil{return fmt.Errorf("no pude preparar el receptor: %w",err)}
  return nil
}
func uninstall() error {
  // No dejes un host privilegiado huérfano al quitar el gestor por usuario.
  query:=exec.Command("reg.exe","query",`HKLM\SYSTEM\CurrentControlSet\Services\RustDesk`,"/v","ImagePath")
  query.SysProcAttr=&syscall.SysProcAttr{HideWindow:true}
  if data,err:=query.CombinedOutput();err==nil && strings.Contains(strings.ToLower(string(data)),`\mir\host\rustdesk.exe`){
    return errors.New("El receptor MiR todavía está activo. Primero abrí MiR > Mi equipo / Receptor > Desactivar receptor y comprobá que Windows lo haya detenido. Luego repetí la desinstalación.")
  }
  dir,err:=destDir();if err!=nil{return err}
  ps:=`$ErrorActionPreference='Continue';`+
    `$d=[Environment]::GetFolderPath('Desktop'); $p=[Environment]::GetFolderPath('Programs');`+
    `Remove-Item -LiteralPath (Join-Path $d 'MiR.lnk'),(Join-Path $p 'MiR.lnk') -Force -ErrorAction SilentlyContinue;`+
    `Start-Sleep -Seconds 3; Remove-Item -LiteralPath `+psQuote(dir)+` -Recurse -Force -ErrorAction SilentlyContinue`
  // Remove registry and start detached cleanup AFTER this executable exits.
  cmd:=exec.Command("reg.exe","delete",regKey,"/f")
  cmd.SysProcAttr=&syscall.SysProcAttr{HideWindow:true}
  _=cmd.Run()
  bytes:=utf16.Encode([]rune(ps)); raw:=make([]byte,0,len(bytes)*2)
  for _,v:=range bytes {raw=append(raw,byte(v),byte(v>>8))}
  p:=exec.Command("powershell.exe","-NoProfile","-EncodedCommand",base64.StdEncoding.EncodeToString(raw))
  p.SysProcAttr=&syscall.SysProcAttr{HideWindow:true}
  if err=p.Start();err!=nil{return err}
  _=p.Process.Release()
  return nil
}
func main() {
  if len(os.Args)>1 && os.Args[1]=="--uninstall" {
    if message("MiR - Desinstalar","¿Desinstalar MiR para este usuario?\r\n\r\nSe conservaran tus equipos, configuracion y motor remoto integrado.",0x24)!=6{return}
    if err:=uninstall();err!=nil {message("MiR - Error",err.Error(),0x10)} else {message("MiR","Desinstalación iniciada. Tus datos se conservarán.",0x40)}
    return
  }
  if message("MiR - Instalador", "¿Instalar MiR V1.5 para este usuario?\r\n\r\nSe crearan accesos directos y desinstalador.\r\nEl motor remoto viene incorporado en el paquete autónomo.\r\nTus equipos guardados no se modificaran.",0x24)!=6{return}
  if err:=install();err!=nil {message("MiR - Error",err.Error(),0x10);return}
  dir,_:=destDir()
  if message("MiR | Receptor Windows", "MiR se instaló correctamente.\r\n\r\n¿Querés activar también el RECEPTOR de esta computadora para permitir conexiones desatendidas?\r\n\r\nWindows solicitará permiso de administrador. Si ya existe un receptor anterior, podrás decidir si migrarlo.\r\n\r\nSe recomienda hacerlo localmente, nunca desde una conexión remota.",0x24)==6 {
    helper:=filepath.Join(os.Getenv("LOCALAPPDATA"),"MiRemoto","Runtime","v1.5.0","MiR_Host.exe")
    c:=exec.Command(helper)
    c.Dir=filepath.Dir(helper)
    if err:=c.Start();err!=nil{message("MiR | Receptor",err.Error(),0x10)}else{_ = c.Process.Release()}
  }
  if message("MiR | Instalación completada", "La aplicación MiR está instalada.\r\n\r\n¿Abrir MiR ahora?",0x24)==6 {
    c:=exec.Command(filepath.Join(dir,"MiR.exe"))
    c.Dir=dir
    if err:=c.Start();err!=nil{message("MiR | Error al abrir",err.Error(),0x10)}else{_ = c.Process.Release()}
  }
}