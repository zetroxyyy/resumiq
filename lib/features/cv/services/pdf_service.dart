import 'package:pdf/widgets.dart' as pw;

class PdfService {
  const PdfService();

  Future<List<int>> generateDocument() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Center(
          child: pw.Text('Resumind Generated PDF'),
        ),
      ),
    );
    return pdf.save();
  }
}
