//
//  AMDrawingTool+Freehand.swift
//  AMDrawingView
//
//  Created by Steve Landey on 7/26/18.
//  Copyright © 2018 Asana. All rights reserved.
//

import CoreGraphics

public class PTPenTool: DrawingTool {
  public typealias ShapeType = PTPenShape

  public var name: String { return "PTPen" }
    private var timeprovider: () -> TimeInterval?
    private var viewportprovider: () -> String?
    public var shapeInProgress: PTPenShape?
  public var isProgressive: Bool = true
  public var velocityBasedWidth: Bool = false

  private var lastVelocity: CGPoint = .zero
  // The shape is rendered to a buffer so that if the color is transparent,
  // you see one contiguous line instead of a bunch of overlapping line
  // segments.
  private var shapeInProgressBuffer: UIImage?
  private var drawingSize: CGSize = .zero
  private var alpha: CGFloat = 0

    public init(timer: @escaping () -> TimeInterval,viewport: @escaping () -> String ) {
        self.timeprovider = timer
        self.viewportprovider = viewport
        self.isProgressive = true;
    }

  public func handleTap(context: ToolOperationContext, point: CGPoint) {
  }

  public func handleDragStart(context: ToolOperationContext, point: CGPoint) {
    debugPrint("handleDragStart: ",point)

    drawingSize = context.drawing.size
    var white: CGFloat = 0  // ignored
    context.userSettings.strokeColor?.getWhite(&white, alpha: &self.alpha)
    lastVelocity = .zero
    let shape = PTPenShape()
    shapeInProgress = shape
    shape.start = point
    shape.isFinished = false
    shape.apply(userSettings: context.userSettings)
    shape.strokeColor = shape.strokeColor.withAlphaComponent(1)
    shape.timestamp = self.timeprovider()!
    shape.viewport = self.viewportprovider()!
  }
    func distanceBetweenPoints(firstPoint: CGPoint, secondPoint: CGPoint) -> CGFloat {
        return sqrt(pow((secondPoint.x - firstPoint.x), 2) + pow((secondPoint.y - firstPoint.y), 2))
    }
  public func handleDragContinue(context: ToolOperationContext, point: CGPoint, velocity: CGPoint) {

    guard let shape = shapeInProgress else { return }
    let lastPoint = shape.segments.last?.b ?? shape.start
    let segmentWidth: CGFloat
    debugPrint("handleDragContinue: ",point, distanceBetweenPoints(firstPoint: lastPoint, secondPoint: point))
    if velocityBasedWidth {
      segmentWidth = DrawsanaUtilities.modulatedWidth(
        width: shape.strokeWidth,
        velocity: velocity,
        previousVelocity: lastVelocity,
        previousWidth: shape.segments.last?.width ?? shape.strokeWidth)
    } else {
      segmentWidth = shape.strokeWidth
    }
    if point != lastPoint {
        let ps = PTPenLineSegment(a: lastPoint, b: point, width: segmentWidth,timestamp:self.timeprovider(),viewport: self.viewportprovider())
        shape.add(segment:ps)
    }
    lastVelocity = velocity

  }

  public func handleDragEnd(context: ToolOperationContext, point: CGPoint) {
    debugPrint("handleDragEnd: ",point)
    guard let shapeInProgress = shapeInProgress else { return }
    shapeInProgress.isFinished = true
    shapeInProgress.apply(userSettings: context.userSettings)
    context.operationStack.apply(operation: AddShapeOperation(shape: shapeInProgress))
    self.shapeInProgress = nil
    shapeInProgressBuffer = nil

  }

  public func handleDragCancel(context: ToolOperationContext, point: CGPoint) {
    // No such thing as a cancel for this tool. If this was recognized as a tap,
    // just end the shape normally.
    handleDragEnd(context: context, point: point)
  }

  public func renderShapeInProgress(transientContext: CGContext) {
    //let begin = clock()
    shapeInProgressBuffer = DrawsanaUtilities.renderImage(size: self.shapeInProgress?.boundingBox.size ?? drawingSize) {
      //self.shapeInProgressBuffer?.draw(at: .zero)
      //self.shapeInProgress?.renderLatestSegment(in: $0)
        self.shapeInProgress?.render(in: $0)
    }
    shapeInProgressBuffer?.draw(at: self.shapeInProgress?.boundingBox.origin ?? .zero)
    //NSLog("PTPenTool.renderShapeInProgress: took %0.3f seconds",Double(clock() - begin) / Double(CLOCKS_PER_SEC));

  }
}
