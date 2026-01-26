import { Controller, Get, UseGuards, Request, Response } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { AdminService } from './admin.service';

@Controller('admin')
@UseGuards(AuthGuard('jwt'))
export class AdminController {
  constructor(private readonly adminService: AdminService) { }

  @Get('export-csv')
  async exportCsv(@Request() req: { user: { role: string; teamId: string } }, @Response() res: { status: (c: number) => { json: (obj: object) => void }; set: (obj: object) => void; send: (data: string) => void }) {
    // Check if user is admin
    if (req.user.role !== 'admin') {
      return res.status(403).json({ message: 'Forbidden' });
    }

    const csvData = await this.adminService.exportTeamTodosCsv(req.user.teamId);

    res.set({
      'Content-Type': 'text/csv',
      'Content-Disposition': `attachment; filename="team_todos_${req.user.teamId}.csv"`,
    });

    return res.send(csvData);
  }
}
