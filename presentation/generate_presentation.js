#!/usr/bin/env node

const pptxgen = require("pptxgenjs");
const { html2pptx, generateThumbnails } = require("html2pptx");
const path = require("path");
const fs = require("fs");

async function main() {
  console.log("Creating PowerPoint presentation...");

  // Create new presentation
  const pres = new pptxgen();
  pres.layout = "LAYOUT_16x9";
  pres.author = "FitGauss-PD Analysis";
  pres.title = "CとIを用いたガウス型速度欠損モデル";

  // Slide file paths
  const slideFiles = [
    "slide01_title.html",
    "slide02_objective.html",
    "slide03_model.html",
    "slide04_method_data.html",
    "slide05_method_fitting.html",
    "slide06_method_regression.html",
    "slide07_results_dataset.html",
    "slide08_results_performance.html",
    "slide09_analysis_residuals.html",
    "slide10_analysis_correlation.html",
    "slide11_findings.html",
    "slide12_conclusion.html"
  ];

  // Convert HTML slides to PowerPoint
  for (let i = 0; i < slideFiles.length; i++) {
    const slideFile = slideFiles[i];
    const htmlPath = path.join(__dirname, "slides", slideFile);

    console.log(`Processing slide ${i + 1}/${slideFiles.length}: ${slideFile}`);

    try {
      // Convert HTML to PowerPoint slide
      await html2pptx({
        pptx: pres,
        htmlPath: htmlPath
      });

      // Add images to specific slides
      const currentSlide = pres.slides[pres.slides.length - 1];

      // Slide 7: velocity deficit profile
      if (slideFile === "slide07_results_dataset.html") {
        currentSlide.addImage({
          path: path.join(__dirname, "images", "velocity_deficit_profile_I0.05_C16.0.png"),
          x: 4.2,
          y: 1.2,
          w: 3.0,
          h: 3.0
        });
      }

      // Slide 8: predicted vs measured
      if (slideFile === "slide08_results_performance.html") {
        currentSlide.addImage({
          path: path.join(__dirname, "images", "predicted_vs_measured.png"),
          x: 4.2,
          y: 1.2,
          w: 3.0,
          h: 3.0
        });
      }

      // Slide 9: residuals vs I
      if (slideFile === "slide09_analysis_residuals.html") {
        currentSlide.addImage({
          path: path.join(__dirname, "images", "residual_vs_I.png"),
          x: 4.2,
          y: 1.2,
          w: 3.0,
          h: 3.0
        });
      }

    } catch (error) {
      console.error(`Error processing ${slideFile}:`, error);
    }
  }

  // Save presentation
  const outputPath = path.join(__dirname, "..", "gaussian-wake-model.pptx");
  await pres.writeFile({ fileName: outputPath });
  console.log(`\nPresentation saved to: ${outputPath}`);

  // Generate thumbnails for validation
  console.log("\nGenerating thumbnails...");
  try {
    await generateThumbnails({
      pptxPath: outputPath,
      outputDir: path.join(__dirname, "thumbnails")
    });
    console.log("Thumbnails generated successfully!");
  } catch (error) {
    console.log("Thumbnail generation skipped (optional)");
  }

  console.log("\nDone!");
}

main().catch(console.error);
