//
//  ViewController.swift
//  Lava
//
//  Created by Rafsan Chowdhury on 12/16/17.
//  Copyright © 2017 appimas24. All rights reserved.
//

import UIKit
import ARKit
import CoreMotion

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet weak var sceneView: ARSCNView!
    let configuration = ARWorldTrackingConfiguration()
    let motionManager = CMMotionManager()
    var vehicle = SCNPhysicsVehicle()
    var orientation: CGFloat = 0
    var accelerationValues = [UIAccelerationValue(0), UIAccelerationValue(0)]
    var touched: Int = 0
    override func viewDidLoad() {
        super.viewDidLoad()
        self.sceneView.debugOptions = [ARSCNDebugOptions.showWorldOrigin, ARSCNDebugOptions.showFeaturePoints]
        
        self.configuration.planeDetection = .horizontal
        self.sceneView.session.run(configuration)
        self.sceneView.delegate = self
        self.setUpAccelerometere()
        self.sceneView.showsStatistics = true
        // To detect horizontal surfaces
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let _ = touches.first else {return}
        self.touched += touches.count
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.touched = 0
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // If an anchor (information about orientation, position, size of horizontal surface) is added then will let you know
        guard let planeAnchor = anchor as? ARPlaneAnchor else {return} // If succeds means added plane anchor was added
        
        let concreteNode = createConcrete(planeAnchor: planeAnchor)
        node.addChildNode(concreteNode)
        print("New plane anchor added")
    }
    
    // When more then one anchor is added it removes it 
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // Gets triggered when something is update
        guard let planeAnchor = anchor as? ARPlaneAnchor else {return} // If succeds means added plane anchor was added
        node.enumerateChildNodes { (childNode, _) in
            childNode.removeFromParentNode()
            
        }
        let concreteNode = createConcrete(planeAnchor: planeAnchor)
        node.addChildNode(concreteNode)
        print("Update floor's anchor...")
    }
    
    // Gets alled make device makes an error
    // Gets called whenever anchors get removed
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        guard let _ = anchor as? ARPlaneAnchor else {return} // If succeds means added plane anchor was added
        node.enumerateChildNodes { (childNode, _) in
            childNode.removeFromParentNode()
        }
    }
    
    func createConcrete(planeAnchor: ARPlaneAnchor) -> SCNNode {
        let concreteNode = SCNNode(geometry: SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z)))
        concreteNode.geometry?.firstMaterial?.diffuse.contents = #imageLiteral(resourceName: "concrete")
        concreteNode.geometry?.firstMaterial?.isDoubleSided = true

        concreteNode.position = SCNVector3(planeAnchor.center.x,planeAnchor.center.y,planeAnchor.center.z)
        concreteNode.eulerAngles = SCNVector3(90.degreesToRadians, 0, 0)
        
        let staticBody = SCNPhysicsBody.static() // Fixtures - fixed in one place something that doesn't move but collides body. Not affected by forces
        concreteNode.physicsBody = staticBody
        return concreteNode
    }
    
    @IBAction func addCar(_ sender: Any) {
        guard let pointOfView = sceneView.pointOfView else {return}
        let transform = pointOfView.transform
        let orientation = SCNVector3(-transform.m31,-transform.m32,-transform.m33) // orientation is reversed so add negative
        let location = SCNVector3(transform.m41,transform.m42,transform.m43)
        let currentPostionOfCamera = orientation + location
        
        
        let scene = SCNScene(named: "car.scn")
        let chasis = (scene?.rootNode.childNode(withName: "chasis", recursively: false))!
        
        let frontLeftWheel = chasis.childNode(withName: "frontLeftParent", recursively: false)!
        let frontRightWheel = chasis.childNode(withName: "frontRightParent", recursively: false)!
        let rearLeftWheel = chasis.childNode(withName: "rearLeftParent", recursively: false)!
        let rearRightWheel = chasis.childNode(withName: "rearRightParent", recursively: false)!
        
        let v_frontLeftWheel = SCNPhysicsVehicleWheel(node: frontLeftWheel)
        let v_frontRightWheel = SCNPhysicsVehicleWheel(node: frontRightWheel)
        let v_rearLeftWheel = SCNPhysicsVehicleWheel(node: rearLeftWheel)
        let v_rearRightWheel = SCNPhysicsVehicleWheel(node: rearRightWheel)

        
        
        chasis.position = currentPostionOfCamera
        
        let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(node: chasis, options: [SCNPhysicsShape.Option.keepAsCompound: true])) //
        chasis.physicsBody = body
        body.mass = 1
        self.vehicle = SCNPhysicsVehicle(chassisBody: chasis.physicsBody!, wheels: [v_rearRightWheel, v_rearLeftWheel, v_frontRightWheel, v_frontLeftWheel])
        self.sceneView.scene.physicsWorld.addBehavior(self.vehicle)
        self.sceneView.scene.rootNode.addChildNode(chasis)
    }
    
    func setUpAccelerometere() {
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 1/60
            motionManager.startAccelerometerUpdates(to: .main, withHandler: { (accelerometerData, error) in
                if let error = error {
                    print(error.localizedDescription)
                    return
                }
                self.accelerometerDidChange(acceleration: (accelerometerData?.acceleration)!)
            })
        } else {
            print("Acc not avail")
        }
    }
    
    func accelerometerDidChange (acceleration : CMAcceleration) {
        
        accelerationValues[1] = filtered(previousAcceleration: accelerationValues[1], UpdatedAcceleration: acceleration.y)
        
        accelerationValues[0] = filtered(previousAcceleration: accelerationValues[0], UpdatedAcceleration: acceleration.x)
        
        if acceleration.x > 0 { // reversed when phone is rotated horizontally
            self.orientation = -CGFloat(accelerationValues[1])
        } else {
            self.orientation = CGFloat(acceleration.y)
        }
        
    }
    
    func filtered(previousAcceleration: Double, UpdatedAcceleration: Double) -> Double {
        let kfilteringFactor = 0.5
        return UpdatedAcceleration * kfilteringFactor + previousAcceleration * (1-kfilteringFactor)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didSimulatePhysicsAtTime time: TimeInterval) {
        var engineForce: CGFloat = 0
        var breakingForce: CGFloat = 0

        self.vehicle.setSteeringAngle(-orientation, forWheelAt: 2)
        self.vehicle.setSteeringAngle(-orientation, forWheelAt: 3)
        
        if self.touched == 1 {
            engineForce = 5
        } else if self.touched == 2 {
            engineForce = -5
        } else if self.touched == 3 {
            breakingForce = 100
        } else {
            engineForce = 0
        }
        
        self.vehicle.applyEngineForce(engineForce, forWheelAt: 0)
        self.vehicle.applyEngineForce(engineForce, forWheelAt: 1)
        self.vehicle.applyBrakingForce(breakingForce, forWheelAt: 0)
        self.vehicle.applyBrakingForce(breakingForce, forWheelAt: 1)

    }
}

func +(left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(left.x + right.x, left.y + right.y, left.z + right.z)
}

extension Int {
    var degreesToRadians: Double { return Double(self) * .pi/180}
}

