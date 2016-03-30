//
//  ADOpenGLView.swift
//  ADHelloOpenGL2
//
//  Created by duanhongjin on 16/3/30.
//  Copyright © 2016年 duanhongjin. All rights reserved.
//

import UIKit

struct Vertex {
    var Position: (Float, Float, Float)
    var Color: (Float, Float, Float, Float)
}

class ADOpenGLView: UIView {
    var eaglLayer: CAEAGLLayer?
    var context: EAGLContext?
    var colorRenderBuffer: GLuint = GLuint()
    var positionSlot: GLuint = GLuint()
    var colorSlot: GLuint = GLuint()
    var projectionUniform: GLuint = GLuint()
    var modelViewUniform: GLuint = GLuint()
    var currentRotation: Float = Float()
    var depthRenderBuffer: GLuint = GLuint()
    
    var Vertices = [
        Vertex(Position: (1, -1, 0), Color: (1, 0, 0, 1)),
        Vertex(Position: (1, 1, 0), Color: (0, 1, 0, 1)),
        Vertex(Position: (-1, 1, 0), Color: (0, 0, 1, 1)),
        Vertex(Position: (-1, -1, 0), Color: (0, 0, 0, 1)),
        Vertex(Position: (1, -1, -1), Color: (1, 0, 0, 1)),
        Vertex(Position: (1, 1, -1), Color: (0, 1, 0, 1)),
        Vertex(Position: (-1, 1, -1), Color: (0, 0, 1, 1)),
        Vertex(Position: (-1, -1, -1), Color: (0, 0, 0, 1)),
    ]
    
    var Indices:[GLubyte] = [
        // Front
        0, 1, 2,
        2, 3, 0,
        // Back
        4, 6, 5,
        4, 7, 6,
        // Left
        2, 7, 3,
        7, 6, 2,
        // Right
        0, 4, 1,
        4, 1, 5,
        // Top
        6, 2, 1,
        1, 6, 5,
        // Bottom
        0, 3, 7,
        0, 7, 4
    ]

    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.setupLayer()
        self.setupContext()
        self.setupDepthBuffer()
        self.setupRenderBuffer()
        self.setupFrameBuffer()
        self.compileShaders()
        self.setupVBOs()
        self.setupDisplayLink()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override class func layerClass() -> AnyClass {
        return CAEAGLLayer.self
    }
    
}

extension ADOpenGLView {
    func setupLayer() {
        self.eaglLayer = self.layer as? CAEAGLLayer
        self.eaglLayer?.opaque = true
    }
    
    func setupContext() {
        let api: EAGLRenderingAPI = .OpenGLES2
        self.context = EAGLContext(API: api)
        if self.context == nil {
            print("Failed to initialize OpenGLES 2.0 context")
            exit(1)
        }
        
        if !EAGLContext.setCurrentContext(self.context) {
            print("Failed to set current OpenGL context")
            exit(1)
        }
    }
    
    func setupRenderBuffer() {
        glGenRenderbuffers(1, &self.colorRenderBuffer)
        glBindRenderbuffer(GLenum(GL_RENDERBUFFER), self.colorRenderBuffer)
        self.context!.renderbufferStorage(Int(GL_RENDERBUFFER), fromDrawable: self.eaglLayer)
    }
    
    func setupFrameBuffer() {
        var framebuffer: GLuint = GLuint()
        glGenFramebuffers(1, &framebuffer)
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), framebuffer)
        glFramebufferRenderbuffer(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0), GLenum(GL_RENDERBUFFER), self.colorRenderBuffer)
        glFramebufferRenderbuffer(GLenum(GL_FRAMEBUFFER), GLenum(GL_DEPTH_ATTACHMENT), GLenum(GL_RENDERBUFFER), self.depthRenderBuffer)
    }
    
    func render(displayLink: CADisplayLink) {
        glClearColor(0, 104.0 / 255.0, 55.0 / 255.0, 1.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
        glEnable(GLenum(GL_DEPTH_TEST))
        
        let projection = CC3GLMatrix.matrix()
        let h = 4.0 * self.frame.size.height / self.frame.size.width
        projection.populateFromFrustumLeft(GLfloat(-2), andRight: GLfloat(2), andBottom: GLfloat(-h / 2), andTop: GLfloat(h / 2), andNear: GLfloat(4), andFar: GLfloat(10))
        glUniformMatrix4fv(GLint(self.projectionUniform), 1, 0, projection.glMatrix)
        
        
        let modelView = CC3GLMatrix.matrix()
        modelView.populateFromTranslation(CC3VectorMake(GLfloat(sin(CACurrentMediaTime())), GLfloat(0), GLfloat(-7)))
        
        self.currentRotation += Float(displayLink.duration) * Float(90)
        modelView.rotateBy(CC3VectorMake(self.currentRotation, self.currentRotation, 0))
        
        glUniformMatrix4fv(GLint(self.modelViewUniform), 1, 0, modelView.glMatrix)
        
        glViewport(0, 0, GLsizei(self.frame.size.width), GLsizei(self.frame.size.height))
        
        let positionSlotFirstComponent = UnsafePointer<Int>(bitPattern:0)
        glVertexAttribPointer(self.positionSlot, 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(sizeof(Vertex)), positionSlotFirstComponent)
        
        let colorSlotFirstComponent = UnsafePointer<Int>(bitPattern:sizeof(Float) * 3)
        glVertexAttribPointer(self.colorSlot, 4, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(sizeof(Vertex)), colorSlotFirstComponent)
        
        let vertextBufferOffset = UnsafeMutablePointer<Void>(bitPattern: 0)
        glDrawElements(GLenum(GL_TRIANGLES), GLsizei(self.Indices.count * sizeof(GLubyte)/sizeof(GLubyte)), GLenum(GL_UNSIGNED_BYTE), vertextBufferOffset)
        
        self.context!.presentRenderbuffer(Int(GL_RENDERBUFFER))
    }
    
    func compileShader(shaderName: String, type:GLenum) -> GLuint {
        let shaderPath = NSBundle.mainBundle().pathForResource(shaderName, ofType: "glsl")
        var error: NSError?
        let shaderString: NSString?
        do {
            shaderString = try NSString(contentsOfFile: shaderPath!, encoding: NSUTF8StringEncoding)
        } catch let error1 as NSError {
            error = error1
            shaderString = nil
        }
        
        if error != nil {
            print("Error loading shader: %@", error?.localizedDescription)
            exit(1)
        }
        
        let shaderHandle: GLuint = glCreateShader(type)
        var shaderStringUTF8 = shaderString?.UTF8String
        var shaderStringLength:GLint  = GLint((shaderString?.length)!)
        glShaderSource(shaderHandle, 1, &shaderStringUTF8!, &shaderStringLength)
        
        glCompileShader(shaderHandle)
        
        var compileSuccess: GLint = GLint()
        glGetShaderiv(shaderHandle, GLenum(GL_COMPILE_STATUS), &compileSuccess)
        if compileSuccess == GL_FALSE {
            exit(1)
        }
        
        return shaderHandle
    }
    
    func compileShaders() {
        let vertexShader: GLuint = self.compileShader("SimpleVertex", type: GLenum(GL_VERTEX_SHADER))
        let fragmentShader: GLuint = self.compileShader("SimpleFragment", type: GLenum(GL_FRAGMENT_SHADER))
        
        let programHandle: GLuint = glCreateProgram()
        glAttachShader(programHandle, vertexShader)
        glAttachShader(programHandle, fragmentShader)
        glLinkProgram(programHandle)
        
        var linkSuccess: GLint = GLint()
        glGetProgramiv(programHandle, GLenum(GL_LINK_STATUS), &linkSuccess)
        if linkSuccess == GL_FALSE {
            exit(1)
        }
        
        glUseProgram(programHandle)

        self.positionSlot = GLuint(glGetAttribLocation(programHandle, "Position"))
        self.colorSlot = GLuint(glGetAttribLocation(programHandle, "SourceColor"))
        glEnableVertexAttribArray(self.positionSlot)
        glEnableVertexAttribArray(self.colorSlot)
        
        self.projectionUniform = GLuint(glGetUniformLocation(programHandle, "Projection"))
        self.modelViewUniform = GLuint(glGetUniformLocation(programHandle, "Modelview"))
    }
    
    func setupVBOs() {
        var vertexBuffer: GLuint = GLuint()
        glGenBuffers(1, &vertexBuffer)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
        glBufferData(GLenum(GL_ARRAY_BUFFER), self.Vertices.count * sizeof(Vertex), self.Vertices, GLenum(GL_STATIC_DRAW))
        
        var indexBuffer: GLuint = GLuint()
        glGenBuffers(1, &indexBuffer)
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), indexBuffer)
        glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER), self.Indices.count * sizeof(GLubyte), Indices, GLenum(GL_STATIC_DRAW))
    }
    
    func setupDisplayLink() {
        let displayLink = CADisplayLink(target: self, selector: #selector(ADOpenGLView.render(_:)))
        displayLink.addToRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
    }

    func setupDepthBuffer() {
        glGenRenderbuffers(1, &self.depthRenderBuffer)
        glBindRenderbuffer(GLenum(GL_RENDERBUFFER), self.depthRenderBuffer)
        glRenderbufferStorage(GLenum(GL_RENDERBUFFER), GLenum(GL_DEPTH_COMPONENT16), GLsizei(self.frame.size.width), GLsizei(self.frame.size.height))
    }
    
}
