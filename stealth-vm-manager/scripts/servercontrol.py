#!/usr/bin/env python3
# control-server.py - Servidor HTTP para control remoto
import http.server
import socketserver
import json
import subprocess
import os
from datetime import datetime
import base64

PORT = 5357  # Puerto de mDNS (no sospechoso)
AUTH_TOKEN = "WINDOWS_UPDATE_2024"  # Cambiar en producción

class StealthHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        # Verificar autenticación
        auth = self.headers.get('Authorization', '')
        if not auth or not auth.startswith('Bearer '):
            self.send_response(401)
            self.end_headers()
            return
        
        if auth.split(' ')[1] != AUTH_TOKEN:
            self.send_response(403)
            self.end_headers()
            return
        
        # Procesar comandos
        if self.path == '/status':
            self.handle_status()
        elif self.path.startswith('/vm/start/'):
            vm_name = self.path.split('/')[-1]
            self.handle_vm_start(vm_name)
        elif self.path.startswith('/vm/stop/'):
            vm_name = self.path.split('/')[-1]
            self.handle_vm_stop(vm_name)
        else:
            self.send_response(404)
            self.end_headers()
    
    def handle_status(self):
        """Obtener estado de VMs"""
        try:
            result = subprocess.run(
                ['VBoxManage', 'list', 'runningvms'],
                capture_output=True,
                text=True,
                timeout=10
            )
            vms = [line.split(' ')[0].strip('"') for line in result.stdout.split('\n') if line]
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({
                'status': 'ok',
                'running_vms': vms,
                'timestamp': datetime.now().isoformat()
            }).encode())
        except Exception as e:
            self.send_error(500, str(e))
    
    def handle_vm_start(self, vm_name):
        """Iniciar VM"""
        try:
            subprocess.run(
                ['VBoxManage', 'startvm', vm_name, '--type', 'headless'],
                capture_output=True,
                timeout=30
            )
            self.send_response(200)
            self.end_headers()
        except Exception as e:
            self.send_error(500, str(e))
    
    def handle_vm_stop(self, vm_name):
        """Detener VM"""
        try:
            subprocess.run(
                ['VBoxManage', 'controlvm', vm_name, 'poweroff'],
                capture_output=True,
                timeout=30
            )
            self.send_response(200)
            self.end_headers()
        except Exception as e:
            self.send_error(500, str(e))
    
    def log_message(self, format, *args):
        # No loggear nada para mantener sigilo
        pass

def run_server():
    # Cambiar al directorio de scripts
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    
    # Configurar servidor
    handler = StealthHandler
    with socketserver.TCPServer(("", PORT), handler) as httpd:
        httpd.allow_reuse_address = True
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            pass
        finally:
            httpd.server_close()

if __name__ == "__main__":
    run_server()
