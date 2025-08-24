import React, { useState, useEffect, useRef, useCallback } from 'react';
import {
  Container,
  Box,
  Paper,
  TextField,
  Button,
  Typography,
  Alert,
  Chip,
  CircularProgress,
  Card,
  CardContent,
  AppBar,
  Toolbar,
  IconButton,
  Drawer,
  List,
  ListItem,
  ListItemText,
  ListItemIcon,
  Divider,
  Switch,
  FormControlLabel,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Grid,
  LinearProgress,
  Tooltip,
  Snackbar
} from '@mui/material';
import {
  Send as SendIcon,
  Menu as MenuIcon,
  Chat as ChatIcon,
  Settings as SettingsIcon,
  Info as InfoIcon,
  Delete as DeleteIcon,
  Download as DownloadIcon,
  LightMode as LightModeIcon,
  DarkMode as DarkModeIcon,
  Refresh as RefreshIcon,
  HealthAndSafety as HealthIcon
} from '@mui/icons-material';
import { ThemeProvider, createTheme } from '@mui/material/styles';
import CssBaseline from '@mui/material/CssBaseline';
import ReactMarkdown from 'react-markdown';
import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter';
import { tomorrow } from 'react-syntax-highlighter/dist/esm/styles/prism';

// Types
interface Message {
  id: string;
  content: string;
  isUser: boolean;
  timestamp: Date;
  tokens?: number;
  processingTime?: number;
  error?: string;
}

interface ChatResponse {
  success: boolean;
  response?: string;
  session_id: string;
  tokens_used: number;
  processing_time: number;
  model_used: string;
  error?: string;
  error_type?: string;
}

interface HealthData {
  status: string;
  message: string;
  timestamp: string;
  api_configured: boolean;
  database_status: string;
  system_metrics: {
    cpu_percent: number;
    memory_percent: number;
    disk_percent: number;
    uptime_seconds: number;
  };
  version: string;
}

interface SessionInfo {
  session_id: string;
  created_at: string;
  last_activity: string;
  total_messages: number;
  total_tokens: number;
  avg_response_time: number;
}

const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:8000';

const Claude AI Agent: React.FC = () => {
  // State
  const [messages, setMessages] = useState<Message[]>([]);
  const [inputMessage, setInputMessage] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [sessionId, setSessionId] = useState<string>('');
  const [error, setError] = useState<string | null>(null);
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [darkMode, setDarkMode] = useState(false);
  const [autoScroll, setAutoScroll] = useState(true);
  const [healthData, setHealthData] = useState<HealthData | null>(null);
  const [sessionInfo, setSessionInfo] = useState<SessionInfo | null>(null);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [healthOpen, setHealthOpen] = useState(false);
  const [snackbarOpen, setSnackbarOpen] = useState(false);
  const [snackbarMessage, setSnackbarMessage] = useState('');
  
  // Refs
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  
  // Theme
  const theme = createTheme({
    palette: {
      mode: darkMode ? 'dark' : 'light',
      primary: {
        main: '#1976d2',
      },
      secondary: {
        main: '#dc004e',
      },
    },
    typography: {
      fontFamily: '"Inter", "Roboto", "Helvetica", "Arial", sans-serif',
    },
    shape: {
      borderRadius: 12,
    },
  });

  // Auto-scroll to bottom
  const scrollToBottom = useCallback(() => {
    if (autoScroll && messagesEndRef.current) {
      messagesEndRef.current.scrollIntoView({ behavior: 'smooth' });
    }
  }, [autoScroll]);

  useEffect(() => {
    scrollToBottom();
  }, [messages, scrollToBottom]);

  // Initialize session
  useEffect(() => {
    const storedSessionId = localStorage.getItem('claude_session_id');
    if (storedSessionId) {
      setSessionId(storedSessionId);
      loadSessionInfo(storedSessionId);
    }
    
    // Load theme preference
    const storedTheme = localStorage.getItem('claude_theme');
    if (storedTheme === 'dark') {
      setDarkMode(true);
    }
    
    // Load initial health data
    loadHealthData();
    
    // Set up health check interval
    const healthInterval = setInterval(loadHealthData, 60000); // Every minute
    
    return () => clearInterval(healthInterval);
  }, []);

  // Save theme preference
  useEffect(() => {
    localStorage.setItem('claude_theme', darkMode ? 'dark' : 'light');
  }, [darkMode]);

  const loadHealthData = async () => {
    try {
      const response = await fetch(`${API_BASE_URL}/health`);
      if (response.ok) {
        const data = await response.json();
        setHealthData(data);
      }
    } catch (error) {
      console.error('Failed to load health data:', error);
    }
  };

  const loadSessionInfo = async (sessionId: string) => {
    try {
      const response = await fetch(`${API_BASE_URL}/sessions/${sessionId}`);
      if (response.ok) {
        const data = await response.json();
        setSessionInfo(data);
      }
    } catch (error) {
      console.error('Failed to load session info:', error);
    }
  };

  const sendMessage = async () => {
    if (!inputMessage.trim() || isLoading) return;

    const userMessage: Message = {
      id: Date.now().toString(),
      content: inputMessage,
      isUser: true,
      timestamp: new Date(),
    };

    setMessages(prev => [...prev, userMessage]);
    setInputMessage('');
    setIsLoading(true);
    setError(null);

    try {
      const response = await fetch(`${API_BASE_URL}/chat`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: inputMessage,
          session_id: sessionId || undefined,
          model: 'claude-3-sonnet-20240229',
          max_tokens: 1000,
        }),
      });

      const data: ChatResponse = await response.json();

      if (data.success && data.response) {
        // Update session ID if new
        if (data.session_id && data.session_id !== sessionId) {
          setSessionId(data.session_id);
          localStorage.setItem('claude_session_id', data.session_id);
        }

        const assistantMessage: Message = {
          id: (Date.now() + 1).toString(),
          content: data.response,
          isUser: false,
          timestamp: new Date(),
          tokens: data.tokens_used,
          processingTime: data.processing_time,
        };

        setMessages(prev => [...prev, assistantMessage]);
        
        // Reload session info
        if (data.session_id) {
          loadSessionInfo(data.session_id);
        }
      } else {
        throw new Error(data.error || 'Failed to get response from Claude');
      }
    } catch (error) {
      console.error('Error sending message:', error);
      const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
      setError(errorMessage);
      
      const errorMsgObj: Message = {
        id: (Date.now() + 1).toString(),
        content: `Error: ${errorMessage}`,
        isUser: false,
        timestamp: new Date(),
        error: errorMessage,
      };
      
      setMessages(prev => [...prev, errorMsgObj]);
    } finally {
      setIsLoading(false);
    }
  };

  const handleKeyPress = (event: React.KeyboardEvent) => {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      sendMessage();
    }
  };

  const clearChat = () => {
    setMessages([]);
    setSessionId('');
    localStorage.removeItem('claude_session_id');
    setSessionInfo(null);
    showSnackbar('Chat cleared');
  };

  const exportChat = () => {
    const chatData = {
      session_id: sessionId,
      exported_at: new Date().toISOString(),
      messages: messages.map(msg => ({
        content: msg.content,
        isUser: msg.isUser,
        timestamp: msg.timestamp,
        tokens: msg.tokens,
        processingTime: msg.processingTime,
      })),
      session_info: sessionInfo,
    };
    
    const blob = new Blob([JSON.stringify(chatData, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `claude-chat-${sessionId || 'session'}-${new Date().toISOString().split('T')[0]}.json`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    showSnackbar('Chat exported');
  };

  const showSnackbar = (message: string) => {
    setSnackbarMessage(message);
    setSnackbarOpen(true);
  };

  const formatUptime = (seconds: number) => {
    const days = Math.floor(seconds / 86400);
    const hours = Math.floor((seconds % 86400) / 3600);
    const mins = Math.floor((seconds % 3600) / 60);
    return `${days}d ${hours}h ${mins}m`;
  };

  const MessageComponent: React.FC<{ message: Message }> = ({ message }) => (
    <Box
      sx={{
        display: 'flex',
        justifyContent: message.isUser ? 'flex-end' : 'flex-start',
        mb: 2,
      }}
    >
      <Paper
        elevation={1}
        sx={{
          p: 2,
          maxWidth: '70%',
          bgcolor: message.isUser ? 'primary.main' : 'background.paper',
          color: message.isUser ? 'primary.contrastText' : 'text.primary',
          borderRadius: message.isUser ? '18px 18px 4px 18px' : '18px 18px 18px 4px',
          border: message.error ? '1px solid #f44336' : 'none',
        }}
      >
        {message.isUser ? (
          <Typography variant="body1">{message.content}</Typography>
        ) : (
          <ReactMarkdown
            components={{
              code({ node, inline, className, children, ...props }) {
                const match = /language-(\w+)/.exec(className || '');
                return !inline && match ? (
                  <SyntaxHighlighter
                    style={tomorrow}
                    language={match[1]}
                    PreTag="div"
                    {...props}
                  >
                    {String(children).replace(/\n$/, '')}
                  </SyntaxHighlighter>
                ) : (
                  <code className={className} {...props}>
                    {children}
                  </code>
                );
              },
            }}
          >
            {message.content}
          </ReactMarkdown>
        )}
        
        <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mt: 1 }}>
          <Typography variant="caption" sx={{ opacity: 0.7 }}>
            {message.timestamp.toLocaleTimeString()}
          </Typography>
          {message.tokens && (
            <Chip
              label={`${message.tokens} tokens`}
              size="small"
              variant="outlined"
              sx={{ ml: 1, height: 20 }}
            />
          )}
          {message.processingTime && (
            <Chip
              label={`${message.processingTime.toFixed(2)}s`}
              size="small"
              variant="outlined"
              sx={{ ml: 1, height: 20 }}
            />
          )}
        </Box>
      </Paper>
    </Box>
  );

  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <Box sx={{ flexGrow: 1, height: '100vh', display: 'flex', flexDirection: 'column' }}>
        {/* App Bar */}
        <AppBar position="static" elevation={0}>
          <Toolbar>
            <IconButton
              edge="start"
              color="inherit"
              aria-label="menu"
              onClick={() => setSidebarOpen(true)}
              sx={{ mr: 2 }}
            >
              <MenuIcon />
            </IconButton>
            <ChatIcon sx={{ mr: 1 }} />
            <Typography variant="h6" component="div" sx={{ flexGrow: 1 }}>
              Claude AI Agent
            </Typography>
            {healthData && (
              <Chip
                icon={<HealthIcon />}
                label={healthData.status}
                color={healthData.status === 'healthy' ? 'success' : 'error'}
                variant="outlined"
                sx={{ color: 'white', borderColor: 'white' }}
              />
            )}
            <IconButton color="inherit" onClick={() => setDarkMode(!darkMode)}>
              {darkMode ? <LightModeIcon /> : <DarkModeIcon />}
            </IconButton>
          </Toolbar>
        </AppBar>

        {/* Main Content */}
        <Container maxWidth="lg" sx={{ flexGrow: 1, display: 'flex', flexDirection: 'column', py: 2 }}>
          {/* Session Info */}
          {sessionInfo && (
            <Card sx={{ mb: 2 }}>
              <CardContent sx={{ py: 1 }}>
                <Grid container spacing={2} alignItems="center">
                  <Grid item xs={12} md={6}>
                    <Typography variant="body2" color="text.secondary">
                      Session: {sessionInfo.session_id.substring(0, 8)}...
                    </Typography>
                  </Grid>
                  <Grid item xs={6} md={2}>
                    <Typography variant="body2" color="text.secondary">
                      Messages: {sessionInfo.total_messages}
                    </Typography>
                  </Grid>
                  <Grid item xs={6} md={2}>
                    <Typography variant="body2" color="text.secondary">
                      Tokens: {sessionInfo.total_tokens.toLocaleString()}
                    </Typography>
                  </Grid>
                  <Grid item xs={12} md={2}>
                    <Typography variant="body2" color="text.secondary">
                      Avg Response: {sessionInfo.avg_response_time.toFixed(2)}s
                    </Typography>
                  </Grid>
                </Grid>
              </CardContent>
            </Card>
          )}

          {/* Messages Area */}
          <Paper
            elevation={1}
            sx={{
              flexGrow: 1,
              p: 2,
              mb: 2,
              overflow: 'auto',
              maxHeight: 'calc(100vh - 300px)',
            }}
          >
            {messages.length === 0 ? (
              <Box
                sx={{
                  display: 'flex',
                  flexDirection: 'column',
                  alignItems: 'center',
                  justifyContent: 'center',
                  height: '100%',
                  textAlign: 'center',
                }}
              >
                <ChatIcon sx={{ fontSize: 64, color: 'text.secondary', mb: 2 }} />
                <Typography variant="h5" color="text.secondary" gutterBottom>
                  Welcome to Claude AI Agent
                </Typography>
                <Typography variant="body1" color="text.secondary">
                  Start a conversation by typing a message below.
                </Typography>
              </Box>
            ) : (
              <>
                {messages.map((message) => (
                  <MessageComponent key={message.id} message={message} />
                ))}
                {isLoading && (
                  <Box sx={{ display: 'flex', justifyContent: 'flex-start', mb: 2 }}>
                    <Paper
                      elevation={1}
                      sx={{
                        p: 2,
                        maxWidth: '70%',
                        bgcolor: 'background.paper',
                        borderRadius: '18px 18px 18px 4px',
                      }}
                    >
                      <Box sx={{ display: 'flex', alignItems: 'center' }}>
                        <CircularProgress size={20} sx={{ mr: 2 }} />
                        <Typography variant="body1">Claude is thinking...</Typography>
                      </Box>
                    </Paper>
                  </Box>
                )}
                <div ref={messagesEndRef} />
              </>
            )}
          </Paper>

          {/* Error Display */}
          {error && (
            <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
              {error}
            </Alert>
          )}

          {/* Input Area */}
          <Paper elevation={1} sx={{ p: 2 }}>
            <Box sx={{ display: 'flex', gap: 1 }}>
              <TextField
                ref={inputRef}
                fullWidth
                multiline
                maxRows={4}
                value={inputMessage}
                onChange={(e) => setInputMessage(e.target.value)}
                onKeyPress={handleKeyPress}
                placeholder="Type your message here..."
                disabled={isLoading}
                variant="outlined"
                size="small"
              />
              <Button
                variant="contained"
                onClick={sendMessage}
                disabled={isLoading || !inputMessage.trim()}
                sx={{ minWidth: 'auto', px: 2 }}
              >
                <SendIcon />
              </Button>
            </Box>
          </Paper>
        </Container>

        {/* Sidebar */}
        <Drawer anchor="left" open={sidebarOpen} onClose={() => setSidebarOpen(false)}>
          <Box sx={{ width: 300, p: 2 }}>
            <Typography variant="h6" gutterBottom>
              Claude AI Agent
            </Typography>
            <Divider sx={{ mb: 2 }} />
            
            <List>
              <ListItem button onClick={() => { setSettingsOpen(true); setSidebarOpen(false); }}>
                <ListItemIcon>
                  <SettingsIcon />
                </ListItemIcon>
                <ListItemText primary="Settings" />
              </ListItem>
              
              <ListItem button onClick={() => { setHealthOpen(true); setSidebarOpen(false); }}>
                <ListItemIcon>
                  <InfoIcon />
                </ListItemIcon>
                <ListItemText primary="System Health" />
              </ListItem>
              
              <ListItem button onClick={exportChat}>
                <ListItemIcon>
                  <DownloadIcon />
                </ListItemIcon>
                <ListItemText primary="Export Chat" />
              </ListItem>
              
              <ListItem button onClick={clearChat}>
                <ListItemIcon>
                  <DeleteIcon />
                </ListItemIcon>
                <ListItemText primary="Clear Chat" />
              </ListItem>
            </List>
          </Box>
        </Drawer>

        {/* Settings Dialog */}
        <Dialog open={settingsOpen} onClose={() => setSettingsOpen(false)} maxWidth="sm" fullWidth>
          <DialogTitle>Settings</DialogTitle>
          <DialogContent>
            <Box sx={{ py: 2 }}>
              <FormControlLabel
                control={
                  <Switch
                    checked={darkMode}
                    onChange={(e) => setDarkMode(e.target.checked)}
                  />
                }
                label="Dark Mode"
              />
              <FormControlLabel
                control={
                  <Switch
                    checked={autoScroll}
                    onChange={(e) => setAutoScroll(e.target.checked)}
                  />
                }
                label="Auto-scroll to new messages"
              />
            </Box>
          </DialogContent>
          <DialogActions>
            <Button onClick={() => setSettingsOpen(false)}>Close</Button>
          </DialogActions>
        </Dialog>

        {/* Health Dialog */}
        <Dialog open={healthOpen} onClose={() => setHealthOpen(false)} maxWidth="md" fullWidth>
          <DialogTitle>
            System Health
            <IconButton
              onClick={loadHealthData}
              sx={{ float: 'right' }}
              size="small"
            >
              <RefreshIcon />
            </IconButton>
          </DialogTitle>
          <DialogContent>
            {healthData ? (
              <Box>
                <Grid container spacing={3}>
                  <Grid item xs={12} md={6}>
                    <Card>
                      <CardContent>
                        <Typography variant="h6" gutterBottom>
                          System Status
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                          Status: <Chip label={healthData.status} color="success" size="small" />
                        </Typography>
                        <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
                          API Configured: {healthData.api_configured ? '✅' : '❌'}
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                          Database: {healthData.database_status}
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                          Version: {healthData.version}
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                          Uptime: {formatUptime(healthData.system_metrics.uptime_seconds)}
                        </Typography>
                      </CardContent>
                    </Card>
                  </Grid>
                  
                  <Grid item xs={12} md={6}>
                    <Card>
                      <CardContent>
                        <Typography variant="h6" gutterBottom>
                          System Metrics
                        </Typography>
                        
                        <Box sx={{ mb: 2 }}>
                          <Typography variant="body2" color="text.secondary">
                            CPU Usage: {healthData.system_metrics.cpu_percent.toFixed(1)}%
                          </Typography>
                          <LinearProgress
                            variant="determinate"
                            value={healthData.system_metrics.cpu_percent}
                            sx={{ mt: 0.5 }}
                          />
                        </Box>
                        
                        <Box sx={{ mb: 2 }}>
                          <Typography variant="body2" color="text.secondary">
                            Memory Usage: {healthData.system_metrics.memory_percent.toFixed(1)}%
                          </Typography>
                          <LinearProgress
                            variant="determinate"
                            value={healthData.system_metrics.memory_percent}
                            color={healthData.system_metrics.memory_percent > 80 ? 'error' : 'primary'}
                            sx={{ mt: 0.5 }}
                          />
                        </Box>
                        
                        <Box>
                          <Typography variant="body2" color="text.secondary">
                            Disk Usage: {healthData.system_metrics.disk_percent.toFixed(1)}%
                          </Typography>
                          <LinearProgress
                            variant="determinate"
                            value={healthData.system_metrics.disk_percent}
                            color={healthData.system_metrics.disk_percent > 80 ? 'error' : 'primary'}
                            sx={{ mt: 0.5 }}
                          />
                        </Box>
                      </CardContent>
                    </Card>
                  </Grid>
                </Grid>
              </Box>
            ) : (
              <CircularProgress />
            )}
          </DialogContent>
          <DialogActions>
            <Button onClick={() => setHealthOpen(false)}>Close</Button>
          </DialogActions>
        </Dialog>

        {/* Snackbar */}
        <Snackbar
          open={snackbarOpen}
          autoHideDuration={3000}
          onClose={() => setSnackbarOpen(false)}
          message={snackbarMessage}
        />
      </Box>
    </ThemeProvider>
  );
};

export default ClaudeAIAgent;
