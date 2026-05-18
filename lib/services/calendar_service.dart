import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class CalendarService {
  static Future<void> addToGoogleCalendar({
    required String title,
    required DateTime startTime,
    DateTime? endTime,
    String? description,
    String? location,
  }) async {
    final fmt = DateFormat("yyyyMMdd'T'HHmmss'Z'");
    final startStr = fmt.format(startTime.toUtc());
    final endStr = fmt.format((endTime ?? startTime.add(const Duration(hours: 1))).toUtc());

    final url = Uri.parse(
      'https://www.google.com/calendar/render?action=TEMPLATE'
      '&text=${Uri.encodeComponent(title)}'
      '&dates=$startStr/$endStr'
      '${description != null ? '&details=${Uri.encodeComponent(description)}' : ''}'
      '${location != null ? '&location=${Uri.encodeComponent(location)}' : ''}',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  static String generateIcsContent({
    required String title,
    required DateTime startTime,
    DateTime? endTime,
    String? description,
  }) {
    final fmt = DateFormat("yyyyMMdd'T'HHmmss'Z'");
    final nowStr = fmt.format(DateTime.now().toUtc());
    final startStr = fmt.format(startTime.toUtc());
    final endStr = fmt.format((endTime ?? startTime.add(const Duration(hours: 1))).toUtc());

    return 'BEGIN:VCALENDAR\n'
        'VERSION:2.0\n'
        'PRODID:-//AiBrewGenius//NONSGML v1.0//EN\n'
        'BEGIN:VEVENT\n'
        'UID:${DateTime.now().millisecondsSinceEpoch}@aibrewgenius.com\n'
        'DTSTAMP:$nowStr\n'
        'DTSTART:$startStr\n'
        'DTEND:$endStr\n'
        'SUMMARY:$title\n'
        '${description != null ? 'DESCRIPTION:${description.replaceAll('\n', '\\n')}\n' : ''}'
        'END:VEVENT\n'
        'END:VCALENDAR';
  }
}
