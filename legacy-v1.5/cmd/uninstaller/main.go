// Desinstalador MiR V1 (Windows usuario actual).
// Se niega a quitar el gestor si el receptor integrado sigue activo.
package main
import(
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
const uninstallReg=`HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\MiR-Remote`
func prompt(title,body string,flags uintptr)uintptr{
 p:=syscall.NewLazyDLL("user32.dll").NewProc("MessageBoxW")
 t,_:=syscall.UTF16PtrFromString(title);b,_:=syscall.UTF16PtrFromString(body)
 r,_,_:=p.Call(0,uintptr(unsafe.Pointer(b)),uintptr(unsafe.Pointer(t)),flags)
 return r
}
func psQuote(s string)string{return "'"+strings.ReplaceAll(s,"'","''")+"'"}
func uninstall()error{
 query:=exec.Command("reg.exe","query",`HKLM\SYSTEM\CurrentControlSet\Services\RustDesk`,"/v","ImagePath")
 query.SysProcAttr=&syscall.SysProcAttr{HideWindow:true}
 if data,err:=query.CombinedOutput();err==nil&&strings.Contains(strings.ToLower(string(data)),`\mir\host\rustdesk.exe`){
  return errors.New("El receptor MiR todavía está instalado. Abrí MiR > Mi equipo / Receptor > Desactivar receptor, verificá que esté detenido y después repetí la desinstalación.")
 }
 base:=os.Getenv("LOCALAPPDATA");if base==""{return errors.New("No se conoce LOCALAPPDATA")}
 dir:=filepath.Join(base,"Programs","MiR")
 _=exec.Command("reg.exe","delete",uninstallReg,"/f").Run()
 ps:=`$ErrorActionPreference='Continue';`+
  `$d=[Environment]::GetFolderPath('Desktop'); $m=[Environment]::GetFolderPath('Programs');`+
  `Remove-Item -LiteralPath (Join-Path $d 'MiR.lnk'),(Join-Path $m 'MiR.lnk') -Force -ErrorAction SilentlyContinue;`+
  `Start-Sleep -Seconds 3; Remove-Item -LiteralPath `+psQuote(dir)+` -Recurse -Force -ErrorAction SilentlyContinue;`
 chars:=utf16.Encode([]rune(ps));raw:=make([]byte,0,len(chars)*2)
 for _,n:=range chars{raw=append(raw,byte(n),byte(n>>8))}
 cmd:=exec.Command("powershell.exe","-NoProfile","-EncodedCommand",base64.StdEncoding.EncodeToString(raw))
 cmd.SysProcAttr=&syscall.SysProcAttr{HideWindow:true}
 if err:=cmd.Start();err!=nil{return fmt.Errorf("no se pudo completar la limpieza: %w",err)}
 _=cmd.Process.Release()
 return nil
}
func main(){
 if prompt("MiR | Desinstalar","¿Desinstalar MiR de tu usuario de Windows?\r\n\r\nLos equipos guardados y ajustes personales se conservarán.\r\nSi tenés el receptor activo, primero deberás desactivarlo desde MiR.",0x24)!=6{return}
 if err:=uninstall();err!=nil{prompt("MiR | Desinstalación",err.Error(),0x10);return}
 prompt("MiR | Desinstalación","La desinstalación del gestor se inició correctamente.",0x40)
}