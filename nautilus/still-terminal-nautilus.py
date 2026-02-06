#!/usr/bin/env python3
"""
Nautilus extension to open directories in stillTerminal
"""

import os
import subprocess
from gi.repository import Nautilus, GObject
from urllib.parse import unquote, urlparse


class StillTerminalExtension(GObject.GObject, Nautilus.MenuProvider):
    """Nautilus extension to add stillTerminal context menu option"""
    
    def __init__(self):
        super().__init__()
    
    def _get_file_path(self, file_info):
        """Extract the file path from Nautilus file info"""
        if file_info.get_uri_scheme() != 'file':
            return None
        
        uri = file_info.get_uri()
        path = unquote(urlparse(uri).path)
        return path
    
    def _open_in_still_terminal(self, menu, files):
        """Open the selected directory in stillTerminal"""
        for file_info in files:
            path = self._get_file_path(file_info)
            if path and os.path.isdir(path):
                try:
                    subprocess.Popen(['still-terminal', '-w', path])
                except Exception as e:
                    print(f"Error launching stillTerminal: {e}")
    
    def get_file_items(self, *args):
        """Return menu items for file context menu"""
        # Handle both old and new Nautilus API
        if len(args) == 1:
            files = args[0]
        else:
            files = args[1]
        
        # Only show menu item if all selected items are directories
        if not files:
            return []
        
        for file_info in files:
            if not file_info.is_directory():
                return []
        
        # Create the menu item
        item = Nautilus.MenuItem(
            name='StillTerminalExtension::OpenInStillTerminal',
            label='Open in stillTerminal',
            tip='Open this directory in stillTerminal'
        )
        
        item.connect('activate', self._open_in_still_terminal, files)
        
        return [item]
    
    def get_background_items(self, *args):
        """Return menu items for background context menu"""
        # Handle both old and new Nautilus API
        if len(args) == 1:
            file_info = args[0]
        else:
            file_info = args[1]
        
        if not file_info:
            return []
        
        path = self._get_file_path(file_info)
        if not path or not os.path.isdir(path):
            return []
        
        # Create the menu item for background click
        item = Nautilus.MenuItem(
            name='StillTerminalExtension::OpenInStillTerminalBackground',
            label='Open in stillTerminal',
            tip='Open this directory in stillTerminal'
        )
        
        item.connect('activate', self._open_in_still_terminal, [file_info])
        
        return [item]
