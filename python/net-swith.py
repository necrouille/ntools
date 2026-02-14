#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script pour basculer entre Wi-Fi et Ethernet sur Windows
Nécessite les droits administrateur
"""

import tkinter as tk
from tkinter import messagebox
import subprocess
import sys
import os
import ctypes


def is_admin():
    """Vérifie si le script est exécuté en tant qu'administrateur"""
    try:
        return os.getuid() == 0
    except AttributeError:
        # Sur Windows, vérifier avec ctypes
        return ctypes.windll.shell32.IsUserAnAdmin() != 0


def run_as_admin():
    """Relance le script avec les privilèges administrateur"""
    if is_admin():
        return True
    else:
        # Relancer le script avec les privilèges administrateur
        script = sys.executable
        params = ' '.join([f'"{arg}"' for arg in sys.argv])
        try:
            # ShellExecuteW avec runas pour demander l'élévation
            ctypes.windll.shell32.ShellExecuteW(
                None,
                "runas",  # Demander l'élévation de privilèges
                script,
                params,
                None,
                1  # SW_SHOWNORMAL
            )
        except Exception as e:
            print(f"Erreur lors de la demande d'élévation: {e}")
            return False
        return False  # Retourner False car on relance le script


def get_network_interfaces():
    """Récupère les noms des interfaces réseau disponibles"""
    try:
        result = subprocess.run(
            ['netsh', 'interface', 'show', 'interface'],
            capture_output=True,
            text=True,
            check=True,
            shell=True
        )
        interfaces = {}
        lines = result.stdout.split('\n')
        
        # Parser la sortie de netsh
        # Format typique: "Connexion au réseau local * 1    Wi-Fi    Activé"
        for line in lines:
            line = line.strip()
            if not line or 'Admin State' in line or 'State' in line:
                continue
            
            # Chercher Wi-Fi
            if ('Wi-Fi' in line or 'WLAN' in line) and 'wifi' not in interfaces:
                # Le nom de l'interface est généralement après l'état
                parts = line.split()
                # Chercher le nom qui contient Wi-Fi ou WLAN
                for i, part in enumerate(parts):
                    if 'Wi-Fi' in part or 'WLAN' in part:
                        # Le nom peut être sur plusieurs mots
                        interface_name = ' '.join(parts[i:])
                        # Nettoyer le nom (enlever les états)
                        if 'Activé' in interface_name or 'Désactivé' in interface_name:
                            interface_name = interface_name.split('Activé')[0].split('Désactivé')[0].strip()
                        interfaces['wifi'] = interface_name
                        break
            
            # Chercher Ethernet
            if ('Ethernet' in line or 'LAN' in line) and 'ethernet' not in interfaces:
                parts = line.split()
                for i, part in enumerate(parts):
                    if 'Ethernet' in part:
                        interface_name = ' '.join(parts[i:])
                        if 'Activé' in interface_name or 'Désactivé' in interface_name:
                            interface_name = interface_name.split('Activé')[0].split('Désactivé')[0].strip()
                        interfaces['ethernet'] = interface_name
                        break
        
        # Valeurs par défaut si non trouvées
        if 'wifi' not in interfaces:
            interfaces['wifi'] = 'Wi-Fi'
        if 'ethernet' not in interfaces:
            interfaces['ethernet'] = 'Ethernet'
            
        return interfaces
    except Exception as e:
        print(f"Erreur lors de la récupération des interfaces: {e}")
        # Valeurs par défaut
        return {'wifi': 'Wi-Fi', 'ethernet': 'Ethernet'}


def set_interface_state(interface_name, state):
    """Active ou désactive une interface réseau"""
    try:
        # Format correct pour netsh sur Windows
        cmd = ['netsh', 'interface', 'set', 'interface', 
               f'name={interface_name}', f'admin={state}']
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True,
            shell=True  # Nécessaire sur Windows pour certaines commandes
        )
        return True
    except subprocess.CalledProcessError as e:
        print(f"Erreur lors de la modification de l'interface {interface_name}: {e}")
        print(f"Sortie: {e.stdout}")
        print(f"Erreur: {e.stderr}")
        return False


def switch_to_ethernet():
    """Désactive Wi-Fi et active Ethernet"""
    interfaces = get_network_interfaces()
    
    wifi_name = interfaces.get('wifi', 'Wi-Fi')
    ethernet_name = interfaces.get('ethernet', 'Ethernet')
    
    success = True
    if wifi_name:
        success = set_interface_state(wifi_name, 'disable') and success
    if ethernet_name:
        success = set_interface_state(ethernet_name, 'enable') and success
    
    if success:
        messagebox.showinfo("Succès", f"Wi-Fi désactivé\nEthernet activé")
        root.quit()
    else:
        messagebox.showerror("Erreur", "Impossible de modifier les interfaces réseau")


def switch_to_wifi():
    """Désactive Ethernet et active Wi-Fi"""
    interfaces = get_network_interfaces()
    
    wifi_name = interfaces.get('wifi', 'Wi-Fi')
    ethernet_name = interfaces.get('ethernet', 'Ethernet')
    
    success = True
    if ethernet_name:
        success = set_interface_state(ethernet_name, 'disable') and success
    if wifi_name:
        success = set_interface_state(wifi_name, 'enable') and success
    
    if success:
        messagebox.showinfo("Succès", f"Ethernet désactivé\nWi-Fi activé")
        root.quit()
    else:
        messagebox.showerror("Erreur", "Impossible de modifier les interfaces réseau")


def create_button(parent, text, image_path=None, command=None):
    """Crée un bouton carré de 100x100 pixels"""
    # Créer une Frame pour contrôler précisément la taille
    frame = tk.Frame(parent, width=100, height=100)
    frame.pack_propagate(False)  # Empêcher la frame de s'adapter au contenu
    
    btn = tk.Button(
        frame,
        text=text,
        command=command,
        font=('Arial', 9, 'bold'),
        relief=tk.RAISED,
        bd=2
    )
    btn.pack(fill=tk.BOTH, expand=True)
    
    # Si une image est fournie, l'utiliser et la redimensionner à 100x100
    if image_path and os.path.exists(image_path):
        try:
            img = tk.PhotoImage(file=image_path)
            original_width = img.width()
            original_height = img.height()
            
            # Redimensionner l'image à 100x100 pixels
            # Calculer les facteurs de redimensionnement
            if original_width > 100 or original_height > 100:
                # Réduire l'image
                width_factor = max(1, original_width // 100)
                height_factor = max(1, original_height // 100)
                img = img.subsample(width_factor, height_factor)
            
            # Ajuster finement si nécessaire
            current_width = img.width()
            current_height = img.height()
            if current_width < 100:
                zoom_x = 100 // current_width
                img = img.zoom(zoom_x, 1)
            if current_height < 100:
                zoom_y = 100 // current_height
                img = img.zoom(1, zoom_y)
            
            btn.config(image=img, compound=tk.CENTER, text="")
            btn.image = img  # Garder une référence
        except Exception as e:
            print(f"Impossible de charger l'image {image_path}: {e}")
    
    return frame


# Vérification et élévation des droits administrateur
if not is_admin():
    # Relancer automatiquement avec les privilèges administrateur
    if not run_as_admin():
        # Si l'élévation a échoué, afficher un message
        try:
            temp_root = tk.Tk()
            temp_root.withdraw()
            messagebox.showerror(
                "Droits administrateur requis",
                "Ce script doit être exécuté en tant qu'administrateur.\n"
                "Une demande d'élévation de privilèges va apparaître."
            )
            temp_root.destroy()
        except:
            pass
    sys.exit(0)  # Quitter le processus actuel (le nouveau processus avec admin va démarrer)

# Création de la fenêtre principale
root = tk.Tk()
root.title("net-swith")
root.geometry("220x120")  # Taille fixe pour 2 boutons de 100x100 + espacement
root.resizable(False, False)
root.configure(bg='#f0f0f0')

# Centrer la fenêtre
root.update_idletasks()
width = root.winfo_width()
height = root.winfo_height()
x = (root.winfo_screenwidth() // 2) - (width // 2)
y = (root.winfo_screenheight() // 2) - (height // 2)
root.geometry(f'{width}x{height}+{x}+{y}')

# Création d'un conteneur pour les boutons
button_frame = tk.Frame(root, bg='#f0f0f0')
button_frame.pack(expand=True)

# Création des boutons
# Vous pouvez ajouter des images en passant le chemin dans image_path
# Exemple: image_path="path/to/wifi_icon.png"
btn_ethernet = create_button(
    button_frame,
    "Ethernet\nON",
    image_path=None,  # Remplacez par le chemin de l'image si nécessaire (ex: "icons/ethernet.png")
    command=switch_to_ethernet
)
btn_ethernet.pack(side=tk.LEFT, padx=5, pady=10)

btn_wifi = create_button(
    button_frame,
    "Wi-Fi\nON",
    image_path=None,  # Remplacez par le chemin de l'image si nécessaire (ex: "icons/wifi.png")
    command=switch_to_wifi
)
btn_wifi.pack(side=tk.LEFT, padx=5, pady=10)

# Lancer l'interface
root.mainloop()

