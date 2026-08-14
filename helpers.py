import subprocess
import check50
import os
import sys
import urllib.request
import tarfile
import shutil

GHDL_VERSION = "6.0.0"
GHDL_INSTALL_DIR = os.path.expanduser("~/.local/ghdl")
GHDL_BIN = os.path.join(GHDL_INSTALL_DIR, "bin", "ghdl")

def format_output(text):
    """Formatiert die GHDL-Ausgabe"""
    formatted_lines = []
    for line in text.split('\n'):
        if line.strip():
            if ':' in line and '(' in line:
                parts = line.split(':')
                if len(parts) >= 4:
                    msg = ':'.join(parts[3:]).strip()
                    msg = msg.replace('(report note): ', '')
                    formatted_lines.append(msg)
            else:
                formatted_lines.append(line)
    return formatted_lines

def ensure_ghdl():
    """Stellt sicher, dass GHDL als prebuilt binary vorhanden ist"""
    if os.path.exists(GHDL_BIN):
        # GHDL ist bereits installiert
        return
    
    print(f"GHDL wird heruntergeladen und installiert...")
    try:
        # Erstelle das Installationsverzeichnis
        os.makedirs(GHDL_INSTALL_DIR, exist_ok=True)
        
        # Download URL für Linux x86_64 mcode backend
        url = f"https://github.com/ghdl/ghdl/releases/download/v{GHDL_VERSION}/ghdl-mcode-{GHDL_VERSION}-ubuntu24.04-x86_64.tar.gz"
        tar_file = os.path.join(GHDL_INSTALL_DIR, f"ghdl-{GHDL_VERSION}.tar.gz")
        
        print(f"Downloade von {url}...")
        urllib.request.urlretrieve(url, tar_file)
        
        # Entpacke das Archiv
        print("Entpacke GHDL...")
        with tarfile.open(tar_file, "r:gz") as tar:
            tar.extractall(GHDL_INSTALL_DIR)
        
        # Lösche das tar.gz nach dem Entpacken
        os.remove(tar_file)
        
        # Verschiebe die Inhalte aus dem verschachtelten Verzeichnis nach oben
        nested_dir = os.path.join(GHDL_INSTALL_DIR, f"ghdl-mcode-{GHDL_VERSION}-ubuntu24.04-x86_64")
        if os.path.exists(nested_dir):
            # Verschiebe bin/ und lib/ direkt in GHDL_INSTALL_DIR
            for item in os.listdir(nested_dir):
                src = os.path.join(nested_dir, item)
                dst = os.path.join(GHDL_INSTALL_DIR, item)
                if os.path.exists(dst):
                    shutil.rmtree(dst) if os.path.isdir(dst) else os.remove(dst)
                shutil.move(src, dst)
            # Lösche das jetzt leere nested Verzeichnis
            os.rmdir(nested_dir)
        
        # Prüfe ob GHDL erfolgreich installiert wurde
        if not os.path.exists(GHDL_BIN):
            raise Exception(f"GHDL binary nicht gefunden unter {GHDL_BIN}")
        
        print(f"GHDL erfolgreich installiert unter {GHDL_INSTALL_DIR}")
        
    except Exception as e:
        raise Exception(f"GHDL Installation fehlgeschlagen: {str(e)}")

def ensure_vaporview():
    """Stellt sicher, dass vaporview VSCode extension installiert ist"""
    try:
        result = subprocess.run(['code', '--list-extensions'], 
                               capture_output=True, 
                               text=True,
                               check=True)
    except (FileNotFoundError, subprocess.CalledProcessError):
        return
    
    if 'lramseyer.vaporview' not in result.stdout:
        print("Vaporview wird installiert...")
        try:
            subprocess.run(['code', '--install-extension', 'lramseyer.vaporview'], 
                          check=True)
        except subprocess.CalledProcessError:
            print("Vaporview konnte nicht installiert werden (optional)")

def run_testbench(tb_name, vhd_file, tb_file, vcd_file, stop_time="1us"):
    """Führt eine VHDL Testbench aus und gibt formatierte Ausgabe zurück"""
    ensure_ghdl()
    result = subprocess.run(
        [GHDL_BIN, 'elab-run', tb_name, f'--vcd={vcd_file}', f'--stop-time={stop_time}'],
        capture_output=True,
        text=True
    )
    
    # Formatiere stdout und stderr einzeln
    formatted_stdout = format_output(result.stdout)
    formatted_stderr = format_output(result.stderr)
    
    # Kombiniere die Listen
    all_formatted = formatted_stdout + formatted_stderr
    
    # Gib jede Zeile aus
    for line in all_formatted:
        check50.log(line)
    
    return result.stdout + result.stderr

def compile_vhdl(vhd_file):
    """Kompiliert eine VHDL-Datei. Exception bei Fehler."""
    ensure_ghdl()
    analyze_result = subprocess.run([GHDL_BIN, 'analyze', vhd_file], 
                  capture_output=True,
                  text=True)
    
    if analyze_result.returncode != 0:
        error_output = analyze_result.stderr + analyze_result.stdout
        check50.log(f"Compilation errors in {vhd_file}:")
        for line in error_output.split('\n'):
            if line.strip():
                check50.log(line)
        raise check50.Failure(f"{vhd_file} has compilation errors!")

def log_vcd_created(vcd_path):
    """Konsolenausgabe/CS50_log: VCD waveform erstellt"""
    if os.path.exists(vcd_path):
        check50.log(f"Waveform file created \"{os.path.basename(vcd_path)}\". Open this file with VSCode extension \"Vaporview\"")
    else:
        raise check50.Failure("VCD file was not generated!")