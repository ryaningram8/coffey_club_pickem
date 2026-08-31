import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { generatePickSheetPdf } from '../services/pick-sheet.service';
import * as weekService from '../services/week.service';
import { requirePoolCommissioner } from '../lib/middleware';

const idParams = z.object({ id: z.string().min(1) });

export async function pickSheetRoutes(server: FastifyInstance) {
  server.get(
    '/:id/pick-sheet.pdf',
    {
      preHandler: requirePoolCommissioner(async (request) =>
        weekService.getSeasonIdForWeek((request.params as { id: string }).id),
      ),
    },
    async (request, reply) => {
      const { id } = idParams.parse(request.params);
      const pdf = await generatePickSheetPdf(id);
      reply
        .header('Content-Type', 'application/pdf')
        .header('Content-Disposition', `attachment; filename="pick-sheet-${id}.pdf"`)
        .send(pdf);
    },
  );
}
