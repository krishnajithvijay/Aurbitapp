import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import { authRouter } from './routes/auth';
import { postsRouter } from './routes/posts';
import { chatRouter } from './routes/chat';
import { communitiesRouter } from './routes/communities';
import { orbitRouter } from './routes/orbit';
import { notificationsRouter } from './routes/notifications';
import { profileRouter } from './routes/profile';

const app = express();
const PORT = process.env.PORT ?? 3001;

// Security middleware
app.use(helmet());
app.use(morgan('combined'));

// CORS
app.use(cors({
  origin: process.env.FRONTEND_URL ?? 'http://localhost:3000',
  credentials: true,
}));

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/', limiter);

// Health check
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString(), service: 'aurbit-backend' });
});

// Routes
app.use('/api/auth', authRouter);
app.use('/api/posts', postsRouter);
app.use('/api/chat', chatRouter);
app.use('/api/communities', communitiesRouter);
app.use('/api/orbit', orbitRouter);
app.use('/api/notifications', notificationsRouter);
app.use('/api/profile', profileRouter);

// 404
app.use((_req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// Error handler
app.use((err: Error, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(PORT, () => {
  console.log(`🚀 Aurbit backend running on port ${PORT}`);
});

export default app;
