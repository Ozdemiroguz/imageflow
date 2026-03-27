enum ProcessingStep {
  // Face flow: copying → detectingFaces → annotating → generatingThumbnail → saving
  // Doc flow:  copying → detectingText → correctingPerspective → enhancingContrast → generatingPdf → generatingThumbnail → saving
  copying('Preparing image...'),
  detectingFaces('Detecting faces...'),
  detectingText('Recognizing text...'),
  correctingPerspective('Correcting perspective...'),
  enhancingContrast('Enhancing contrast...'),
  annotating('Applying grayscale filter...'),
  generatingPdf('Generating PDF...'),
  generatingThumbnail('Generating thumbnail...'),
  saving('Saving results...'),
  complete('Processing complete');

  const ProcessingStep(this.label);
  final String label;

  /// Determinate progress for face flow (5 steps).
  double get faceProgress => switch (this) {
        copying => 0.0,
        detectingFaces => 0.2,
        annotating => 0.5,
        generatingThumbnail => 0.8,
        saving => 0.9,
        complete => 1.0,
        _ => 0.0,
      };

  /// Determinate progress for document flow (7 steps).
  double get documentProgress => switch (this) {
        copying => 0.0,
        detectingText => 0.1,
        correctingPerspective => 0.3,
        enhancingContrast => 0.5,
        generatingPdf => 0.65,
        generatingThumbnail => 0.85,
        saving => 0.95,
        complete => 1.0,
        _ => 0.0,
      };
}
