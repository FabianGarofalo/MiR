// MiR V1.5 - Creator: bundles the COMPLETE RustDesk runtime directory, not only RustDesk.exe.
// The original installed RustDesk is never altered. Windows amd64 build.
package main

import (
 "archive/zip"
 "crypto/sha256"
 "debug/pe"
 _ "embed"
 "encoding/binary"
 "errors"
 "fmt"
 "io"
 "os"
 "path/filepath"
 "strings"
 "syscall"
 "unsafe"
)

//go:embed MiR_Base.exe
var portable []byte
//go:embed MiR_Instalador_Base.exe
var installer []byte

const magic = "MIR-ENGZIP-2026!" // 16 bytes
const maxArchive int64 = 700 << 20
const maxRaw int64 = 900 << 20

func msg(title, body string, flags uintptr) uintptr {
 p:=syscall.NewLazyDLL("user32.dll").NewProc("MessageBoxW")
 a,_:=syscall.UTF16PtrFromString(title);b,_:=syscall.UTF16PtrFromString(body)
 r,_,_:=p.Call(0,uintptr(unsafe.Pointer(b)),uintptr(unsafe.Pointer(a)),flags)
 return r
}
func chooseMotor() (string,error) {
 if len(os.Args)>1 {
  path,err:=filepath.Abs(strings.Trim(os.Args[1],`"`));if err!=nil{return "",err};return path,nil
 }
 paths:=[]string{}
 if p:=os.Getenv("ProgramFiles");p!=""{paths=append(paths,filepath.Join(p,"RustDesk","RustDesk.exe"))}
 if p:=os.Getenv("ProgramFiles(x86)");p!=""{paths=append(paths,filepath.Join(p,"RustDesk","RustDesk.exe"))}
 if p:=os.Getenv("LOCALAPPDATA");p!="" {
  paths=append(paths,filepath.Join(p,"Programs","RustDesk","RustDesk.exe"),filepath.Join(p,"RustDesk","RustDesk.exe"))
 }
 for _,p:=range paths{if st,err:=os.Stat(p);err==nil&&st.Mode().IsRegular(){return p,nil}}
 return "",errors.New("No encontre RustDesk instalado. Busca la carpeta de instalacion oficial y arrastra RustDesk.exe sobre este creador. No uses el RustDesk.exe extraido por MiR v0.5")
}
func verifyMotor(path string) error {
 if !strings.EqualFold(filepath.Base(path),"RustDesk.exe") {return errors.New("Selecciona exclusivamente el RustDesk.exe oficial (no el instalador de MiR)")}
 f,err:=os.Open(path);if err!=nil{return err};defer f.Close()
 st,err:=f.Stat();if err!=nil{return err}
 if !st.Mode().IsRegular(){return errors.New("RustDesk.exe no es un archivo regular")}
 if st.Size()<100<<10||st.Size()>500<<20{return fmt.Errorf("tamano inusual de RustDesk.exe (%d bytes)",st.Size())}
 executable,err:=pe.NewFile(f);if err!=nil{return fmt.Errorf("RustDesk.exe no es PE Windows valido: %w",err)};defer executable.Close()
 if executable.Machine!=pe.IMAGE_FILE_MACHINE_AMD64{return errors.New("Esta version necesita RustDesk x64. No uses ARM ni x86")}
 // Flutter's main exe can be under 1 MB; it relies on flutter_windows.dll and librustdesk.dll.
 if st.Size()<1<<20 {
  root:=filepath.Dir(path)
  for _,lib:=range []string{"librustdesk.dll","flutter_windows.dll"} {
   if s,e:=os.Stat(filepath.Join(root,lib));e!=nil||s.Size()<1<<20 {
    return fmt.Errorf("RustDesk.exe es pequeno y falta %s. Usa la carpeta COMPLETA de instalacion de RustDesk, no un EXE aislado",lib)
   }
  }
 }
 return nil
}
func exclude(rel string) bool {
 name:=strings.ToLower(filepath.Base(rel))
 if strings.HasPrefix(name,"unins")||strings.HasPrefix(name,"mir_") {return true}
 if name=="thumbs.db"||name=="desktop.ini"{return true}
 ext:=strings.ToLower(filepath.Ext(name))
 switch ext {case ".log",".bak",".tmp",".db",".sqlite",".sqlite3",".pem",".key",".pfx",".p12",".toml",".ini":return true}
 segments:=strings.Split(strings.ToLower(filepath.ToSlash(rel)),"/")
 for _,p:=range segments{if p=="logs"||p=="cache"||p=="config"||p=="sessions"{return true}}
 return false
}
func makeArchive(src string) (string,int64,int,int64,error) {
 root:=filepath.Dir(src)
 tmp,err:=os.CreateTemp("","MiR-RustDesk-*.zip")
 if err!=nil{return "",0,0,0,err}
 cleanup:=func(e error)(string,int64,int,int64,error){tmp.Close();os.Remove(tmp.Name());return "",0,0,0,e}
 zw:=zip.NewWriter(tmp)
 count:=0;var total int64;hasExe:=false
 err=filepath.Walk(root,func(path string,info os.FileInfo,e error) error {
  if e!=nil{return e}
  rel,e:=filepath.Rel(root,path);if e!=nil{return e}
  if rel=="."{return nil}
  if exclude(rel){if info.IsDir(){return filepath.SkipDir};return nil}
  if info.IsDir(){return nil}
  if !info.Mode().IsRegular(){return fmt.Errorf("no se permite enlace o archivo especial: %s",rel)}
  if info.Size()>500<<20{return fmt.Errorf("archivo demasiado grande: %s",rel)}
  total+=info.Size();count++
  if total>maxRaw||count>10000{return errors.New("carpeta de motor demasiado grande")}
  rel=filepath.ToSlash(rel)
  if rel=="RustDesk.exe"{hasExe=true}
  hdr,e:=zip.FileInfoHeader(info);if e!=nil{return e}
  hdr.Name=rel;hdr.Method=zip.Deflate
  dst,e:=zw.CreateHeader(hdr);if e!=nil{return e}
  f,e:=os.Open(path);if e!=nil{return e}
  _,copyErr:=io.Copy(dst,f)
  closeErr:=f.Close()
  if copyErr!=nil{return copyErr}
  return closeErr
 })
 if err!=nil{zw.Close();return cleanup(err)}
 if !hasExe{zw.Close();return cleanup(errors.New("La carpeta no incluye RustDesk.exe"))}
 if err:=zw.Close();err!=nil{return cleanup(err)}
 if err:=tmp.Close();err!=nil{return cleanup(err)}
 st,err:=os.Stat(tmp.Name());if err!=nil{return cleanup(err)}
 if st.Size()<512||st.Size()>maxArchive{return cleanup(errors.New("archivo comprimido fuera del limite"))}
 return tmp.Name(),st.Size(),count,total,nil
}
func makeStandalone(dst string,base []byte,archive string) error {
 source,err:=os.Open(archive);if err!=nil{return err};defer source.Close()
 out,err:=os.Create(dst+".nuevo");if err!=nil{return err}
 fail:=func(e error)error{out.Close();os.Remove(dst+".nuevo");return e}
 if _,err:=out.Write(base);err!=nil{return fail(err)}
 hash:=sha256.New();n,err:=io.Copy(io.MultiWriter(out,hash),source);if err!=nil{return fail(err)}
 if n>maxArchive||n<512{return fail(errors.New("archivo integrado fuera de limite"))}
 if _,err:=out.Write(hash.Sum(nil));err!=nil{return fail(err)}
 var buf[8]byte;binary.LittleEndian.PutUint64(buf[:],uint64(n))
 if _,err:=out.Write(buf[:]);err!=nil{return fail(err)}
 if _,err:=out.Write([]byte(magic));err!=nil{return fail(err)}
 if err:=out.Close();err!=nil{return fail(err)}
 if _,err:=os.Stat(dst);err==nil{
  if err:=os.Remove(dst);err!=nil{return fail(fmt.Errorf("Cerra el ejecutable anterior: %w",err))}
 }
 if err:=os.Rename(dst+".nuevo",dst);err!=nil{return fail(err)}
 return nil
}
func main(){
 src,err:=chooseMotor();if err!=nil{msg("MiR - motor",err.Error(),0x10);return}
 if err:=verifyMotor(src);err!=nil{msg("MiR - motor no apto",err.Error(),0x10);return}
 st,_:=os.Stat(src)
 if msg("MiR V1.5 - Motor completo",fmt.Sprintf("Carpeta oficial encontrada:\r\n%s\r\n\r\nRustDesk.exe: %.1f MB.\r\nSe empaquetara toda la carpeta de ejecucion (DLL y data).\r\nEl proceso NO modifica el RustDesk instalado.\r\nNo cambia contraseñas. La instalación ofrecerá activar el receptor de MiR.\r\n\r\nContinuar?",filepath.Dir(src),float64(st.Size())/1048576),0x24)!=6{return}
 archive,size,files,raw,err:=makeArchive(src)
 if err!=nil{msg("MiR - error al empaquetar",err.Error(),0x10);return}
 defer os.Remove(archive)
 self,err:=os.Executable();if err!=nil{msg("MiR",err.Error(),0x10);return}
 dir:=filepath.Dir(self)
 portableDest:=filepath.Join(dir,"MiR_V1.5_Portable.exe")
 installDest:=filepath.Join(dir,"MiR_V1.5_Instalador.exe")
 if err:=makeStandalone(portableDest,portable,archive);err!=nil{msg("MiR - error portable",err.Error(),0x10);return}
 if err:=makeStandalone(installDest,installer,archive);err!=nil{msg("MiR - error instalador",err.Error(),0x10);return}
 notice:="MiR V1.5 incorpora un motor RustDesk original provisto por el usuario, sin modificar.\r\n"+
  "Proyecto RustDesk: https://github.com/rustdesk/rustdesk\r\nLicencia: GNU AGPL-3.0 (conservar avisos y obligaciones aplicables).\r\n"+
  "La instalación ofrece activar explícitamente el servicio de recepción de MiR en cada equipo.\r\n"
 _=os.WriteFile(filepath.Join(dir,"MiR_AVISO_LICENCIAS.txt"),[]byte(notice),0644)
 msg("MiR V1.5 - completado",fmt.Sprintf("Se crearon portable e instalador MiR V1.5.\r\n\r\nMotor empaquetado: %d archivos (%.1f MB antes / %.1f MB comprimido).\r\n\r\n%s\r\n%s\r\n\r\nPROBA PRIMERO EL PORTABLE. No desinstales el RustDesk que recibe sesiones.",files,float64(raw)/1048576,float64(size)/1048576,filepath.Base(portableDest),filepath.Base(installDest)),0x40)
}