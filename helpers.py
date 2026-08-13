import subprocess
import check50
import os

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
    """Stellt sicher, dass GHDL installiert ist"""
    try:
        subprocess.run(['ghdl', '--version'], 
                      capture_output=True, 
                      check=True)
    except (FileNotFoundError, subprocess.CalledProcessError):
        print("GHDL wird installiert...")
        try:
            subprocess.run(['sudo', 'apt', 'update'], check=True)
            subprocess.run(['sudo', 'apt', 'install', '-y', 'ghdl'], check=True)
        except subprocess.CalledProcessError as e:
            raise Exception("GHDL Installation fehlgeschlagen: " + str(e))

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
    result = subprocess.run(
        ['ghdl', 'elab-run', tb_name, f'--vcd={vcd_file}', f'--stop-time={stop_time}'],
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
    analyze_result = subprocess.run(['ghdl', 'analyze', vhd_file], 
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