require 'sketchup.rb'

# In Ruby console in sketchup
# load "C:/Users/clinu/GitHub/sketchup-plugin/src/align/main.rb"
#

module PSF
    module Align

class AlignTool

  @face1
  @face2
  @pt1
  @pt2

  def activate
    puts "Align activated"
  end

  def deactivate(view)
    puts "Align deactivated"
  end

  def onLButtonUp(flags, x, y, view)
    ph = view.pick_helper
    ph.do_pick(x, y)
    entities = ph.all_picked
    ray = view.pickray(x, y)
    puts "ray #{ray}"
    for entity in entities do
      if entity.is_a?(Sketchup::Face)
        if @face1.nil?
          @face1 = entity;
          @pt1 = self.ray_face_intersection(ray, @face1)
        else
          @face2 = entity;
          @pt2 = self.ray_face_intersection(ray, @face2)
          self.do_align
        end
        break;
      end
    end
  end

  def ray_face_intersection(ray, face)
    ro = ray[0]
    rd = ray[1]
    plane = face.plane
    # n.pt + d = 0
    # n.(ro + rd.t) + d = 0
    # n.ro + n.rd.t + d = 0
    # n.rd.t = -(n.ro + d)
    # t = -(n.ro + d) / (n.rd)
    t = -(plane[0] * ro.x + plane[1] * ro.y + plane[2] * ro.z + plane[3]) / (plane[0] * rd.x + plane[1] * rd.y + plane[2] * rd.z)
    rd2 = Geom::Vector3d.new(rd.x * t, rd.y * t, rd.z * t);
    puts "rd.z * t = #{rd.z * t}"
    pt = ro + rd2
    puts "t #{t}"
    puts "pt #{pt}"
    return pt
  end

  def do_align
    model = Sketchup.active_model
    model.start_operation('Align', true)
    puts "Two faces selected"
    plane1 = @face1.plane
    plane2 = @face2.plane
    pt1 = @pt1
    pt2 = @pt2
    puts "Face 1 plane: #{plane1}, point: #{pt1}"
    puts "Face 2 plane: #{plane2}, point: #{pt2}"
    n1 = Geom::Vector3d.new(plane1[0], plane1[1], plane1[2])
    n2 = Geom::Vector3d.new(plane2[0], plane2[1], plane2[2])
    ca = n1 % n2
    a = Math.acos(ca)
    if a.abs() > 0.001 * Math::PI / 180
      rot_vec = (n1 * n2).normalize
      t = Geom::Transformation.rotation(pt1, rot_vec, a)
      @face1.parent.entities.transform_entities(t, @face1.all_connected)
    end
    movement = pt2 - pt1
    t2 = Geom::Transformation.translation(movement)
    @face1.parent.entities.transform_entities(t2, @face1.all_connected)
    model.commit_operation
    Sketchup.active_model.select_tool(nil)
  end

end

def self.align
  tool = AlignTool.new
  Sketchup.active_model.select_tool(tool)
end

unless file_loaded?(__FILE__)
  menu = UI.menu('Plugins')
  menu.add_item('Align') {
    self.align
  }

  file_loaded(__FILE__)
end

    end # module Align
end # module PSF
