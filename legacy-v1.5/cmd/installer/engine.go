package main

import (
 "archive/zip"
 "bytes"
 "crypto/sha256"
 "encoding/binary"
 "errors"
 "fmt"
 "io"
 "os"
 "path/filepath"
 "strings"
)

// Engine bundle v0.6 contains the complete RustDesk runtime DIRECTORY as a ZIP.
// Footer: archive SHA-256 (32), archive byte count (8 LE), magic (16).
const engineMagic = "MIR-ENGZIP-2026!"
const engineArchiveMax int64 = 700 << 20
const engineExtractMax int64 = 900 << 20

func bundledEngineArchive() (*os.File, int64, int64, [32]byte, bool, error) {
 var expected [32]byte
 exe, err:=os.Executable();if err!=nil{return nil,0,0,expected,false,err}
 f,err:=os.Open(exe);if err!=nil{return nil,0,0,expected,false,err}
 st,err:=f.Stat();if err!=nil{f.Close();return nil,0,0,expected,false,err}
 if st.Size()<56{f.Close();return nil,0,0,expected,false,nil}
 footer:=make([]byte,56)
 if _,err=f.ReadAt(footer,st.Size()-56);err!=nil{f.Close();return nil,0,0,expected,false,err}
 if string(footer[40:])!=engineMagic{f.Close();return nil,0,0,expected,false,nil}
 count:=int64(binary.LittleEndian.Uint64(footer[32:40]))
 if count<512||count>engineArchiveMax||count>st.Size()-56{f.Close();return nil,0,0,expected,false,fmt.Errorf("archivo integrado incompleto o tamano incorrecto (%d bytes)",count)}
 copy(expected[:],footer[:32]);start:=st.Size()-56-count
 return f,start,count,expected,true,nil
}

func checkArchive(f *os.File,start,count int64,expected [32]byte) error {
 h:=sha256.New()
 if _,err:=io.Copy(h,io.NewSectionReader(f,start,count));err!=nil{return err}
 if !bytes.Equal(h.Sum(nil),expected[:]){return errors.New("el archivo integrado no supera la verificacion SHA-256")}
 return nil
}

func archiveEntryName(n string) (string,error) {
 n=strings.ReplaceAll(n,"\\","/")
 if n==""||strings.HasPrefix(n,"/")||strings.Contains(n,":")||strings.ContainsRune(n,0){return "",errors.New("ruta de motor invalida")}
 for _,part:=range strings.Split(n,"/") {if part==""||part=="."||part==".."{return "",errors.New("entrada sospechosa en archivos del motor")}}
 path:=filepath.Clean(filepath.FromSlash(n))
 if path=="."||filepath.IsAbs(path)||path==".."||strings.HasPrefix(path,".."+string(filepath.Separator)){return "",errors.New("ruta fuera de destino")}
 return path,nil
}

func installEngineIfBundled() error {
 f,start,n,expected,exists,err:=bundledEngineArchive()
 if err!=nil{return err}
 if !exists{return nil}
 defer f.Close()
 base:=os.Getenv("LOCALAPPDATA")
 if base=="" {return errors.New("Windows no informo LOCALAPPDATA")}
 root:=filepath.Join(base,"MiRemoto","Engine")
 final:=filepath.Join(root,"v1.0")
 stamp:=filepath.Join(final,"MiR_Engine_SHA256.txt")
 hashtext:=fmt.Sprintf("%x",expected[:])
 if data,err:=os.ReadFile(stamp);err==nil&&strings.TrimSpace(string(data))==hashtext {
  if info,err:=os.Stat(filepath.Join(final,"RustDesk.exe"));err==nil&&info.Size()>0{return nil}
 }
 if err:=checkArchive(f,start,n,expected);err!=nil{return err}
 zr,err:=zip.NewReader(io.NewSectionReader(f,start,n),n);if err!=nil{return fmt.Errorf("no pude abrir el paquete de RustDesk: %w",err)}
 if len(zr.File)<1||len(zr.File)>10000{return errors.New("numero de archivos de motor invalido")}
 if err=os.MkdirAll(root,0700);err!=nil{return err}
 temp,err:=os.MkdirTemp(root,".mir-motor-");if err!=nil{return err}
 defer os.RemoveAll(temp)
 var total int64
 var sawExe bool
 for _,entry:=range zr.File {
  name,err:=archiveEntryName(entry.Name);if err!=nil{return err}
  if entry.Mode()&os.ModeSymlink!=0{return errors.New("el paquete contiene un enlace simbolico inesperado")}
  if entry.FileInfo().IsDir(){return errors.New("estructura inesperada del paquete")}
  if !entry.Mode().IsRegular(){return errors.New("archivo de tipo no permitido")}
  if entry.UncompressedSize64>500<<20{return errors.New("archivo individual demasiado grande")}
  total+=int64(entry.UncompressedSize64)
  if total>engineExtractMax{return errors.New("el motor supera el limite total de extraccion")}
  if strings.EqualFold(filepath.ToSlash(name),"RustDesk.exe"){sawExe=true}
  dst:=filepath.Join(temp,name)
  if err:=os.MkdirAll(filepath.Dir(dst),0700);err!=nil{return err}
  rc,err:=entry.Open();if err!=nil{return err}
  out,err:=os.OpenFile(dst,os.O_WRONLY|os.O_CREATE|os.O_EXCL,0600)
  if err!=nil{rc.Close();return err}
  readN,copyErr:=io.Copy(out,io.LimitReader(rc,int64(entry.UncompressedSize64)+1))
  closeErr:=out.Close();rc.Close()
  if copyErr!=nil{return copyErr};if closeErr!=nil{return closeErr}
  if uint64(readN)!=entry.UncompressedSize64{return fmt.Errorf("tamano corrupto en %s",entry.Name)}
 }
 if !sawExe{return errors.New("faltaba RustDesk.exe dentro del paquete")}
 if err:=os.WriteFile(filepath.Join(temp,"MiR_Engine_SHA256.txt"),[]byte(hashtext+"\r\n"),0600);err!=nil{return err}
 backup:=final+".anterior"
 if _,err:=os.Stat(final);err==nil {
  if err:=os.RemoveAll(backup);err!=nil{return fmt.Errorf("no pude liberar respaldo anterior: %w",err)}
  if err:=os.Rename(final,backup);err!=nil{return fmt.Errorf("cierra sesiones remotas activas antes de actualizar el motor: %w",err)}
 }
 if err:=os.Rename(temp,final);err!=nil{
  if _,e:=os.Stat(backup);e==nil{_ = os.Rename(backup,final)}
  return fmt.Errorf("no pude activar el motor: %w",err)
 }
 _=os.RemoveAll(backup)
 return nil
}