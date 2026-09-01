import PDFDocument from 'pdfkit';
import { getWeekWithGames, type GameDto } from './week.service';

const PAGE_MARGIN = 40;
const COLUMN_GAP = 24;
const BLANK = '______';
const NAME_FONT_SIZE = 13;
const HEADER_FONT_SIZE = 12;
const SUBTITLE_FONT_SIZE = 9;
const ROW_GAP = 4;
const BLOCK_GAP = 16;

/**
 * Renders a printable paper pick sheet for a week, mirroring the legacy
 * Google Sheets layout: a blank name line up top, "Visitor" / "Home"
 * column headers, then one row per game — day/time (+ network, when
 * known) above a blank line *before* each team name (so it's unambiguous
 * which team the mark belongs to), visitor and home side by side. No
 * standings/payouts/tiebreaker section by design (see
 * PAPER_PICK_SHEET_FEATURE.md). `network` is only populated for games
 * assigned after the network column was added — older already-assigned
 * games render without it.
 */
export async function generatePickSheetPdf(weekId: string): Promise<Buffer> {
  const week = await getWeekWithGames(weekId);

  const doc = new PDFDocument({ size: 'LETTER', margin: PAGE_MARGIN });
  const chunks: Buffer[] = [];
  doc.on('data', (chunk) => chunks.push(chunk));
  const done = new Promise<Buffer>((resolve) => {
    doc.on('end', () => resolve(Buffer.concat(chunks)));
  });

  const pageWidth = doc.page.width - PAGE_MARGIN * 2;
  const columnWidth = (pageWidth - COLUMN_GAP) / 2;
  const columnX = [PAGE_MARGIN, PAGE_MARGIN + columnWidth + COLUMN_GAP];
  const bottomY = doc.page.height - PAGE_MARGIN;

  doc.font('Helvetica').fontSize(NAME_FONT_SIZE);
  const blankWidth = doc.widthOfString(`${BLANK}  `);
  const nameWidth = columnWidth - blankWidth;
  doc.fontSize(SUBTITLE_FONT_SIZE);
  const subtitleHeight = doc.heightOfString('X');

  function drawHeader(): number {
    doc.font('Helvetica-Bold').fontSize(20).text(`${week.label} — Pick Sheet`, PAGE_MARGIN, PAGE_MARGIN, {
      width: pageWidth,
    });
    const afterTitleY = doc.y + 6;
    doc
      .font('Helvetica')
      .fontSize(12)
      .text('Name: _______________________________________________', PAGE_MARGIN, afterTitleY, {
        width: pageWidth,
      });
    const afterNameY = doc.y + 6;
    doc.text('Email: ______________________________________________', PAGE_MARGIN, afterNameY, {
      width: pageWidth,
    });
    return doc.y + 16;
  }

  function drawColumnHeaders(y: number): number {
    doc.font('Helvetica-Bold').fontSize(HEADER_FONT_SIZE).fillColor('#000000');
    doc.text('Visitor', columnX[0], y, { width: columnWidth });
    doc.text('Home (unless noted)', columnX[1], y, { width: columnWidth });
    return y + doc.heightOfString('Visitor', { width: columnWidth }) + 10;
  }

  function teamCellHeight(teamName: string): number {
    doc.font('Helvetica-Bold').fontSize(NAME_FONT_SIZE);
    return Math.max(doc.heightOfString(teamName, { width: nameWidth }), 16);
  }

  function drawTeamCell(x: number, y: number, teamName: string): number {
    doc.font('Helvetica').fontSize(NAME_FONT_SIZE).fillColor('#000000');
    doc.text(BLANK, x, y);
    doc.font('Helvetica-Bold').fontSize(NAME_FONT_SIZE);
    doc.text(teamName, x + blankWidth, y, { width: nameWidth });
    return teamCellHeight(teamName);
  }

  function rowHeight(game: GameDto): number {
    const awayHeight = teamCellHeight(game.awayTeam.name);
    const homeHeight = teamCellHeight(game.homeTeam.name);
    return subtitleHeight + ROW_GAP + Math.max(awayHeight, homeHeight) + BLOCK_GAP;
  }

  function drawGameRow(y: number, game: GameDto) {
    const kickoff = new Date(game.gameTime).toLocaleString('en-US', {
      weekday: 'short',
      hour: 'numeric',
      minute: '2-digit',
      timeZone: 'America/Chicago',
    });
    const subtitle = game.network ? `${kickoff} · ${game.network}` : kickoff;

    doc.font('Helvetica').fontSize(SUBTITLE_FONT_SIZE).fillColor('#555555');
    doc.text(subtitle, PAGE_MARGIN, y, { width: pageWidth });

    const cellY = y + subtitleHeight + ROW_GAP;
    drawTeamCell(columnX[0], cellY, game.awayTeam.name);
    drawTeamCell(columnX[1], cellY, game.homeTeam.name);
  }

  let y = drawColumnHeaders(drawHeader());

  for (const game of week.games) {
    const height = rowHeight(game);
    if (y + height > bottomY) {
      doc.addPage();
      y = drawColumnHeaders(PAGE_MARGIN);
    }
    drawGameRow(y, game);
    y += height;
  }

  doc.end();
  return done;
}
