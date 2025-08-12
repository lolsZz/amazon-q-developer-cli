#!/usr/bin/env python3
"""
Script to view and analyze Amazon Q CLI audit logs
"""
import json
import os
import glob
from datetime import datetime
from pathlib import Path

def find_audit_directory():
    """Find the audit directory based on environment"""
    # Check for snap environment first
    snap_dir = Path.home() / "snap" / "code" / "*" / ".local" / "share" / "amazon-q-cli" / "audit"
    snap_matches = glob.glob(str(snap_dir))
    if snap_matches:
        return Path(snap_matches[0])
    
    # Check standard XDG location
    xdg_data = os.environ.get('XDG_DATA_HOME', Path.home() / ".local" / "share")
    standard_dir = Path(xdg_data) / "amazon-q-cli" / "audit"
    if standard_dir.exists():
        return standard_dir
    
    return None

def load_session_events(session_file):
    """Load all events from a session file"""
    events = []
    try:
        with open(session_file, 'r') as f:
            for line in f:
                if line.strip():
                    events.append(json.loads(line))
    except Exception as e:
        print(f"Error reading {session_file}: {e}")
    return events

def format_timestamp(ts_str):
    """Format timestamp for display"""
    try:
        dt = datetime.fromisoformat(ts_str.replace('Z', '+00:00'))
        return dt.strftime('%Y-%m-%d %H:%M:%S')
    except:
        return ts_str

def print_tool_execution(event):
    """Print tool execution details"""
    data = event['data']
    if event['type'] == 'tool_execute_start':
        print(f"  🔧 Started: {data['tool_name']}")
        if 'mcp_server' in data and data['mcp_server']:
            print(f"      Server: {data['mcp_server']}")
    elif event['type'] == 'tool_execute_end':
        status = data['status']
        emoji = "✅" if status == "success" else "❌"
        print(f"  {emoji} Finished: {status}")
        if 'output' in data:
            output = data['output']
            if len(output) > 200:
                print(f"      Output: {output[:200]}...")
            else:
                print(f"      Output: {output}")
        if 'duration_ms' in data:
            print(f"      Duration: {data['duration_ms']}ms")

def analyze_session(session_file):
    """Analyze a single session"""
    events = load_session_events(session_file)
    if not events:
        return
    
    session_id = events[0]['session_id']
    print(f"\n📋 Session: {session_id}")
    print(f"📄 File: {session_file.name}")
    
    tool_count = 0
    mcp_tool_count = 0
    
    for event in events:
        ts = format_timestamp(event['ts'])
        event_type = event['type']
        
        if event_type == 'session_start':
            data = event['data']
            print(f"  ⏰ Started: {ts}")
            print(f"  🤖 Model: {data.get('model_id', 'Unknown')}")
            print(f"  💬 Interactive: {data.get('interactive', False)}")
        
        elif event_type == 'user_input':
            user_input = event['data']['input']
            if len(user_input) > 100:
                user_input = user_input[:100] + "..."
            print(f"  👤 Input: {user_input}")
        
        elif event_type == 'tool_execute_start':
            tool_count += 1
            if event['data'].get('mcp_server'):
                mcp_tool_count += 1
            print_tool_execution(event)
        
        elif event_type == 'tool_execute_end':
            print_tool_execution(event)
        
        elif event_type == 'session_end':
            print(f"  🔚 Ended: {ts}")
    
    print(f"  📊 Total tools: {tool_count} (MCP: {mcp_tool_count})")

def main():
    audit_dir = find_audit_directory()
    if not audit_dir:
        print("❌ No audit directory found")
        return
    
    print(f"📁 Audit directory: {audit_dir}")
    
    # Find all session files
    session_files = list(audit_dir.glob("session-*.jsonl"))
    if not session_files:
        print("❌ No session files found")
        return
    
    # Sort by modification time (newest first)
    session_files.sort(key=lambda x: x.stat().st_mtime, reverse=True)
    
    print(f"📊 Found {len(session_files)} session files")
    
    # Show latest sessions
    for session_file in session_files[:5]:  # Show latest 5
        analyze_session(session_file)

if __name__ == "__main__":
    main()
