const isDev = process.env.NODE_ENV !== 'production';

export const logger = isDev
  ? {
      transport: {
        target: 'pino-pretty',
        options: { colorize: true },
      },
    }
  : true;
