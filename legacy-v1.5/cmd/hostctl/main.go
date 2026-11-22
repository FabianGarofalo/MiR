// MiR V1 - asistente local de receptor desatendido para Windows x64.
// No desinstala ni reemplaza servicios preexistentes sin consentimiento explícito.
// Utiliza el motor previamente incorporado por el usuario y conserva sus avisos legales.
package main

import (
  "errors"
  "fmt"
  "io"
  "os"
  "os/exec"
  "path/filepath"
  "regexp"
  "strings"
  "syscall"
  "time"
  "unsafe"
)

const serviceName = "RustDesk" // Identificador técnico requerido por el motor subyacente.

func popup(title, msg string, flags uintptr) uintptr {
  proc := syscall.NewLazyDLL("user32.dll").NewProc("MessageBoxW")
  t,_:=syscall.UTF16PtrFromString(title); s,_:=syscall.UTF16PtrFromString(msg)
  ret,_,_:=proc.Call(0,uintptr(unsafe.Pointer(s)),uintptr(unsafe.Pointer(t)),flags)
  return ret
}
func admin() bool {
  v,_,_:=syscall.NewLazyDLL("shell32.dll").NewProc("IsUserAnAdmin").Call()
  return v != 0
}
func elevate() error {
  self,err:=os.Executable();if err!=nil{return err}
  verb,_:=syscall.UTF16PtrFromString("runas")
  path,_:=syscall.UTF16PtrFromString(self)
  param,_:=syscall.UTF16PtrFromString("--activate-elevated")
  dir,_:=syscall.UTF16PtrFromString(filepath.Dir(self))
  code,_,e:=syscall.NewLazyDLL("shell32.dll").NewProc("ShellExecuteW").Call(0,uintptr(unsafe.Pointer(verb)),uintptr(unsafe.Pointer(path)),uintptr(unsafe.Pointer(param)),uintptr(unsafe.Pointer(dir)),1)
  if code<=32{return fmt.Errorf("Windows no autorizó la elevación: %v",e)}
  return nil
}
func cmdOut(timeout time.Duration, name string, args ...string) (string,error){
  cmd:=exec.Command(name,args...)
  cmd.SysProcAttr=&syscall.SysProcAttr{HideWindow:true}
  // The commands here are fixed; no shell interpolation, no user arguments.
  done:=make(chan struct{})
  var output []byte
  var err error
  go func(){output,err=cmd.CombinedOutput();close(done)}()
  select {
  case <-done:return strings.TrimSpace(string(output)),err
  case <-time.After(timeout):
    if cmd.Process!=nil{_ = cmd.Process.Kill()}
    <-done
    return strings.TrimSpace(string(output)),errors.New("el proceso superó el tiempo de espera")
  }
}
func servicePath() (string,bool,error) {
  // Registry identifiers are invariant across Spanish/English Windows installations.
  out,err:=cmdOut(12*time.Second,"reg.exe","query",`HKLM\SYSTEM\CurrentControlSet\Services\RustDesk`,"/v","ImagePath")
  if err!=nil{return "",false,nil} // La clave no existe o no es accesible.
  expr:=regexp.MustCompile(`(?im)^\s*ImagePath\s+REG_(?:EXPAND_)?SZ\s+(.+?)\s*$`)
  sub:=expr.FindStringSubmatch(out)
  if len(sub)<2 {return "",true,errors.New("el servicio existe, pero no se pudo leer la ruta registrada")}
  return strings.TrimSpace(os.ExpandEnv(sub[1])),true,nil
}
func getExe(command string) string{
  m:=regexp.MustCompile(`(?i)^\s*"([^"]+\.exe)"|^\s*(.+?\.exe)(?:\s|$)`).FindStringSubmatch(command)
  if len(m)<3{return ""};if m[1]!="" {return m[1]};return strings.TrimSpace(m[2])
}
func bundledSource() (string,error) {
  base:=os.Getenv("LOCALAPPDATA")
  if base==""{return "",errors.New("Windows no informó LOCALAPPDATA")}
  dir:=filepath.Join(base,"MiRemoto","Engine","v1.0")
  for _,name:=range []string{"RustDesk.exe","librustdesk.dll","flutter_windows.dll"}{
    f:=filepath.Join(dir,name)
    if s,err:=os.Stat(f);err!=nil||s.IsDir(){return "",fmt.Errorf("falta un archivo del motor incorporado: %s",name)}
  }
  if _,err:=os.Stat(filepath.Join(dir,"MiR_Engine_SHA256.txt"));err!=nil{return "",errors.New("el motor no tiene su comprobante de integridad")}
  return dir,nil
}
func hostDestination()(string,error){
  base:=os.Getenv("ProgramFiles")
  if base=="" {base=`C:\Program Files`}
  return filepath.Join(base,"MiR","Host"),nil
}
func copyFile(src,dst string) error{
  in,err:=os.Open(src);if err!=nil{return err};defer in.Close()
  info,err:=in.Stat();if err!=nil{return err}
  if info.Size()>500<<20{return fmt.Errorf("archivo del motor demasiado grande: %s",filepath.Base(src))}
  out,err:=os.OpenFile(dst,os.O_CREATE|os.O_EXCL|os.O_WRONLY,0600);if err!=nil{return err}
  _,err=io.Copy(out,in);closeErr:=out.Close();if err!=nil{return err};return closeErr
}
func stageHost(source, dest string) error{
  if _,err:=os.Stat(dest);err==nil{return errors.New("Ya existe el directorio del receptor; no se sobrescribirán archivos. Revisá el estado desde MiR")}
  parent:=filepath.Dir(dest)
  if err:=os.MkdirAll(parent,0755);err!=nil{return err}
  tmp,err:=os.MkdirTemp(parent,".MiR-host-");if err!=nil{return err};defer os.RemoveAll(tmp)
  err=filepath.Walk(source,func(path string,info os.FileInfo,walkErr error)error{
    if walkErr!=nil{return walkErr}
    rel,err:=filepath.Rel(source,path);if err!=nil{return err}
    if rel=="." {return nil}
    target:=filepath.Join(tmp,rel)
    if info.IsDir(){return os.MkdirAll(target,0755)}
    if !info.Mode().IsRegular(){return fmt.Errorf("archivo especial no permitido: %s",rel)}
    if err:=os.MkdirAll(filepath.Dir(target),0755);err!=nil{return err}
    return copyFile(path,target)
  })
  if err!=nil{return err}
  // Directorio inmutable mientras el servicio está en funcionamiento.
  return os.Rename(tmp,dest)
}
func serviceIsRunning() bool {
  text,err:=cmdOut(12*time.Second,"sc.exe","query",serviceName)
  return err==nil&&(strings.Contains(strings.ToUpper(text),"RUNNING")||regexp.MustCompile(`(?im)^\s*(?:STATE|ESTADO)\s*:\s*4\b`).MatchString(text))
}
func waitRemoved() bool {
  for i:=0;i<12;i++ {_,exists,_:=servicePath();if !exists{return true};time.Sleep(700*time.Millisecond)}
  return false
}
// Use Windows Service Control Manager (SCM) directly. The GUI runtime is NOT a CLI
// installer and must never be launched with captured stdout / a timeout.
func createService(command string, label string) error {
  out,err:=cmdOut(25*time.Second,"sc.exe","create",serviceName,
    "binPath=",command,"start=","auto","DisplayName=",label)
  if err!=nil{return fmt.Errorf("Windows no registró el receptor (%v): %s",err,shortMsg(out))}
  return nil
}
func shortMsg(in string) string {
  in=strings.ReplaceAll(strings.TrimSpace(in),"\r","")
  if len(in)>450 {in=in[:450]+"..."}
  return in
}
func stopIfRunning() error {
  if !serviceIsRunning(){return nil}
  out,err:=cmdOut(25*time.Second,"sc.exe","stop",serviceName)
  if err!=nil {return fmt.Errorf("Windows no detuvo el receptor anterior: %s (%v)",shortMsg(out),err)}
  for i:=0;i<25;i++ {if !serviceIsRunning(){return nil};time.Sleep(600*time.Millisecond)}
  return errors.New("el receptor anterior sigue en ejecución: cancelé la migración para proteger el acceso")
}
func deleteService() error {
  out,err:=cmdOut(25*time.Second,"sc.exe","delete",serviceName)
  if err!=nil{return fmt.Errorf("no se pudo liberar el registro del servicio: %s (%v)",shortMsg(out),err)}
  if !waitRemoved(){return errors.New("Windows dejó el servicio pendiente de eliminación. Cerrá otras aplicaciones de administración y reiniciá antes de volver a probar")}
  return nil
}
func startAndVerify(exe string) error {
  path,found,err:=servicePath();if err!=nil{return err};if !found{return errors.New("Windows no registró el servicio")}
  if !strings.EqualFold(filepath.Clean(getExe(path)),filepath.Clean(exe)){
    return errors.New("Windows registró una ruta de servicio distinta de la esperada")
  }
  out,err:=cmdOut(30*time.Second,"sc.exe","start",serviceName)
  if err!=nil && !serviceIsRunning(){return fmt.Errorf("Windows no pudo iniciar el receptor: %s (%v)",shortMsg(out),err)}
  for i:=0;i<22;i++{if serviceIsRunning(){return nil};time.Sleep(650*time.Millisecond)}
  return errors.New("el receptor está registrado pero no alcanzó el estado EN EJECUCIÓN")
}
func installService(exe string) error {
  if err:=createService(`"`+exe+`" --service`,"MiR Receptor");err!=nil{return err}
  return startAndVerify(exe)
}
func restorePrevious(oldCommand string, oldWasRunning bool) error {
  // Keep the original full ImagePath (including original arguments).
  if _,found,_:=servicePath();found {
    _=stopIfRunning()
    _=deleteService()
  }
  if err:=createService(oldCommand,"Receptor anterior");err!=nil{return err}
  oldExe:=getExe(oldCommand)
  if oldExe==""{return errors.New("ruta anterior vacía")}
  path,found,err:=servicePath()
  if err!=nil||!found||!strings.EqualFold(filepath.Clean(getExe(path)),filepath.Clean(oldExe)){
    return errors.New("Windows no confirmó la restauración del registro anterior")
  }
  if oldWasRunning{return startAndVerify(oldExe)}
  return nil
}
func migrateOld(oldCommand, newExe string) error {
  oldExe:=getExe(oldCommand)
  if oldExe==""{return errors.New("no se pudo identificar la ruta del receptor anterior")}
  if _,err:=os.Stat(oldExe);err!=nil{return errors.New("el archivo del receptor anterior no está disponible; no voy a migrarlo sin una vía de recuperación")}
  oldWasRunning:=serviceIsRunning()
  if err:=stopIfRunning();err!=nil{return err}
  if err:=deleteService();err!=nil{
    // If deletion has failed, don't attempt to install a second service.
    return err
  }
  if err:=installService(newExe);err!=nil{
    restoreErr:=restorePrevious(oldCommand,oldWasRunning)
    if restoreErr!=nil {
      return fmt.Errorf("NO SE COMPLETÓ LA MIGRACIÓN: %v. ATENCIÓN: tampoco se confirmó la restauración (%v). Revisá el servicio localmente",err,restoreErr)
    }
    return fmt.Errorf("MiR no pudo iniciar el receptor nuevo: %v. Se restauró el registro del receptor anterior; verificá el acceso antes de reiniciar",err)
  }
  return nil
}
func activate() error {
  src,err:=bundledSource();if err!=nil{return err}
  dest,_:=hostDestination();destExe:=filepath.Join(dest,"RustDesk.exe")
  prev,found,err:=servicePath();if err!=nil{return err}
  if found && strings.EqualFold(filepath.Clean(getExe(prev)),filepath.Clean(destExe)){
    if serviceIsRunning(){popup("MiR | Receptor","El receptor MiR ya está activado y funcionando.",0x40);return nil}
    _,_=cmdOut(20*time.Second,"sc.exe","start",serviceName)
    if serviceIsRunning(){popup("MiR | Receptor","El receptor MiR se inició correctamente.",0x40);return nil}
    return errors.New("el servicio MiR está registrado pero no arranca; revisá los eventos de Windows")
  }
  if found {
    if popup("MiR | Migración del receptor",
      "Se detectó un servicio remoto anterior en esta PC.\r\n\r\n"+
      "Para que MiR sea el receptor integrado, es necesario detener ese servicio y registrar el receptor de MiR.\r\n"+
      "La conexión actual puede interrumpirse y el identificador puede variar.\r\n\r\n"+
      "Hacé este cambio físicamente en la PC, NO desde una sesión remota.\r\n"+
      "No se borrarán contraseñas ni configuración. Se intentará restaurar el servicio previo si falla la instalación.\r\n\r\n¿Autorizar la migración?",0x34)!=6 {
      return nil
    }
  }else{
    if popup("MiR | Activar recepción",
      "MiR instalará un servicio de Windows para recibir conexiones incluso antes de iniciar sesión.\r\n\r\n"+
      "El servicio utiliza el motor remoto integrado y se iniciará con Windows.\r\n"+
      "No se crearán contraseñas y deberás configurar las tuyas.\r\n\r\n¿Instalar el receptor MiR?",0x24)!=6{return nil}
  }
  if _,err:=os.Stat(dest);os.IsNotExist(err){
    if err:=stageHost(src,dest);err!=nil{return err}
  }else if err!=nil{return err}
  for _,name:=range []string{"RustDesk.exe","librustdesk.dll","flutter_windows.dll"} {
    if _,e:=os.Stat(filepath.Join(dest,name));e!=nil{return fmt.Errorf("receptor integrado incompleto, falta %s; no se modificó el servicio",name)}
  }
  if found {
    if err:=migrateOld(prev,destExe);err!=nil{return err}
  }else if err:=installService(destExe);err!=nil{
    // A fresh installation must not leave a broken service registered.
    if path,exists,_:=servicePath();exists && strings.EqualFold(filepath.Clean(getExe(path)),filepath.Clean(destExe)) {
      _=stopIfRunning()
      _=deleteService()
    }
    return fmt.Errorf("no se activó el receptor; no se tocó ningún servicio previo: %w",err)
  }
  popup("MiR | Receptor activado","El servicio de recepción se instaló y Windows confirma que está en ejecución.\r\n\r\nAhora verificá el ID, configurá una contraseña permanente robusta y probá la conexión desde otra máquina.",0x40)
  return nil
}
func deactivate() error {
  dst,_:=hostDestination()
  own:=filepath.Join(dst,"RustDesk.exe")
  service,exists,err:=servicePath();if err!=nil{return err}
  if !exists {popup("MiR | Receptor","No hay un receptor instalado como servicio en esta PC.",0x40);return nil}
  if !strings.EqualFold(filepath.Clean(getExe(service)),filepath.Clean(own)){
    return errors.New("este servicio no pertenece a MiR. Para proteger las conexiones actuales, no se modificó")
  }
  if popup("MiR | Desactivar receptor","¿Desactivar el servicio MiR de esta computadora?\r\n\r\nEl equipo dejará de recibir conexiones antes del inicio de sesión. Si estás conectándote remotamente, perderás el acceso.\r\n\r\n¿Continuar?",0x34)!=6{return nil}
  if err:=stopIfRunning();err!=nil{return err}
  if err:=deleteService();err!=nil{return err}
  popup("MiR | Receptor","El servicio receptor quedó desactivado. Tu listado de equipos y tus credenciales no se han borrado.",0x40)
  return nil
}
func main(){
  deactivateMode:=len(os.Args)>1&&(os.Args[1]=="--deactivate"||os.Args[1]=="--deactivate-elevated")
  if !admin(){
    self,err:=os.Executable();if err!=nil{popup("MiR | Error",err.Error(),0x10);return}
    verb,_:=syscall.UTF16PtrFromString("runas")
    path,_:=syscall.UTF16PtrFromString(self)
    args:="--activate-elevated";if deactivateMode{args="--deactivate-elevated"}
    param,_:=syscall.UTF16PtrFromString(args)
    dir,_:=syscall.UTF16PtrFromString(filepath.Dir(self))
    code,_,e:=syscall.NewLazyDLL("shell32.dll").NewProc("ShellExecuteW").Call(0,uintptr(unsafe.Pointer(verb)),uintptr(unsafe.Pointer(path)),uintptr(unsafe.Pointer(param)),uintptr(unsafe.Pointer(dir)),1)
    if code<=32 {popup("MiR | Permisos",fmt.Sprintf("Windows no autorizó el cambio: %v",e),0x10)}
    return
  }
  var err error
  if deactivateMode{err=deactivate()}else{err=activate()}
  if err!=nil{popup("MiR | Aviso del receptor",err.Error(),0x10);os.Exit(1)}
}