require 'sketchup.rb'

# In Ruby console in sketchup
# load "C:/Users/clinu/GitHub/sketchup-plugin/src/align/main.rb"
#

module PSF
    module Align

class AlignTool

  @face1
  @face2
  @reverseNormal1
  @reverseNormal2
  @parents1
  @parents2
  @pt1
  @pt2

  def activate
    puts "Align activated"
  end

  def deactivate(view)
    puts "Align deactivated"
  end

  def onLButtonUp(flags, x, y, view)
    ray = view.pickray(x, y)
    ph = view.pick_helper
    ph.do_pick(x, y)
=begin
    entities = ph.all_picked
    faces = find_all_faces(entities)
    closestFaceParents = nil
    closestDist = nil
    for face_parents in faces do
      face = face_parents[0]
      t = ray_face_intersection_time(ray, face)
      if closestDist.nil? || t < closestDist
        closestDist = t
        closestFaceParents = face_parents
      end
    end
=end
    face = ph.picked_face
    entities = ph.all_picked
    parents = []
    if entities.count > 0
      entity = entities[0]
      if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
        parents << entity
      end
    end
    if face.nil?
      closestFaceParents = nil
    else
      closestFaceParents = [face, parents]
    end
    if !closestFaceParents.nil?
      if @face1.nil?
        @face1 = closestFaceParents[0]
        @parents1 = closestFaceParents[1]
        world_transformation = combind_parent_transformations(@parents1)
        plane = transform_plane(@face1.plane, world_transformation)
        @pt1 = self.ray_plane_intersection(ray, plane)
        @reverseNormal1 = ray[1].dot(Geom::Vector3d::new(plane[0], plane[1], plane[2])) > 0.0
      else
        @face2 = closestFaceParents[0]
        @parents2 = closestFaceParents[1]
        world_transformation = combind_parent_transformations(@parents2)
        plane = transform_plane(@face2.plane, world_transformation)
        @pt2 = self.ray_plane_intersection(ray, plane)
        @reverseNormal1 = ray[1].dot(Geom::Vector3d::new(plane[0], plane[1], plane[2])) > 0.0
        self.do_align
      end
    end
  end

  # returns: [face, parent[]][]
  def find_all_faces(entities)
    faces = []
    entities.each{|entity|
      if entity.is_a?(Sketchup::Face)
        faces << [entity, []]
      elsif entity.is_a?(Sketchup::Group)
        for face_parents in find_all_faces(entity.entities) do
          face = face_parents[0]
          parents = face_parents[1]
          parents2 = []
          for parent in parents do
            parents2 << parent
          end
          parents2 << entity
          faces << [face, parents2]
        end
      end
    }
    return faces
  end

  def ray_plane_intersection_time(ray, plane)
    ro = ray[0]
    rd = ray[1]
    # n.pt + d = 0
    # n.(ro + rd.t) + d = 0
    # n.ro + n.rd.t + d = 0
    # n.rd.t = -(n.ro + d)
    # t = -(n.ro + d) / (n.rd)
    t = -(plane[0] * ro.x + plane[1] * ro.y + plane[2] * ro.z + plane[3]) / (plane[0] * rd.x + plane[1] * rd.y + plane[2] * rd.z)
    return t;
  end

  def ray_plane_intersection(ray, plane)
    ro = ray[0]
    rd = ray[1]
    t = ray_plane_intersection_time(ray, plane)
    rd2 = Geom::Vector3d.new(rd.x * t, rd.y * t, rd.z * t);
    pt = ro + rd2
    return pt
  end

  def ray_face_intersection_time(ray, face)
    ro = ray[0]
    rd = ray[1]
    plane = face.plane
    # n.pt + d = 0
    # n.(ro + rd.t) + d = 0
    # n.ro + n.rd.t + d = 0
    # n.rd.t = -(n.ro + d)
    # t = -(n.ro + d) / (n.rd)
    t = -(plane[0] * ro.x + plane[1] * ro.y + plane[2] * ro.z + plane[3]) / (plane[0] * rd.x + plane[1] * rd.y + plane[2] * rd.z)
    return t;
  end

  def ray_face_intersection(ray, face)
    ro = ray[0]
    rd = ray[1]
    t = ray_face_intersection_time(ray, face)
    rd2 = Geom::Vector3d.new(rd.x * t, rd.y * t, rd.z * t);
    pt = ro + rd2
    return pt
  end

  def do_align
    model = Sketchup.active_model
    model.start_operation('Align', true)
    puts "Two faces selected"
    world_transformation1 = combind_parent_transformations(@parents1)
    world_transformation2 = combind_parent_transformations(@parents2)
    plane1 = transform_plane(@face1.plane, world_transformation1)
    plane2 = transform_plane(@face2.plane, world_transformation2)
    pt1 = @pt1
    pt2 = @pt2
    puts "Face 1 plane: #{plane1}, point: #{pt1}"
    puts "Face 2 plane: #{plane2}, point: #{pt2}"
    n1 = Geom::Vector3d.new(plane1[0], plane1[1], plane1[2])
    n2 = Geom::Vector3d.new(plane2[0], plane2[1], plane2[2])
    if @reverseNormal1
      n1 = Geom::Vector3d::new(-n1.x, -n1.y, -n1.z)
    end
    if @reverseNormal2
      n2 = Geom::Vector3d::new(-n2.x, -n2.y, -n2.z)
    end
    tmp = Geom::Vector3d::new(-n1.x, -n1.y, -n1.z)
    ca = tmp % n2
    a = Math.acos(ca)
    if a.abs() > 0.001 * Math::PI / 180 && a.abs() < Math::PI - 0.001 * Math::PI / 180
      rot_vec = (n1 * n2).normalize
      t = Geom::Transformation.rotation(pt1, rot_vec, -a)
      if @parents1.length != 0
        @parents1[0].transform!(t)
      else
        @face1.parent.entities.transform_entities(t, @face1.all_connected)
      end
    end
    tmp = (pt2 - pt1).dot(n2)
    movement = Geom::Vector3d::new(n2.x * tmp, n2.y * tmp, n2.z * tmp)
    t2 = Geom::Transformation.translation(movement)
    if @parents1.length != 0
      @parents1[0].transform!(t2)
    else
      @face1.parent.entities.transform_entities(t2, @face1.all_connected)
    end
    model.commit_operation
    Sketchup.active_model.select_tool(nil)
  end

  def transform_plane(plane, transformation)
    n = Geom::Vector3d.new(plane[0], plane[1], plane[2])
    d = plane[3]
    tmp = scale_vector(n, -d)
    k = Geom::Point3d.new(tmp.x, tmp.y, tmp.z)
    n2 = transformation * n
    tmp = transformation * k
    k2 = Geom::Vector3d.new(tmp.x, tmp.y, tmp.z)
    d2 = -n2.dot(k2)
    return [n2.x, n2.y, n2.z, d2]
  end

  def get_face_world_plane(face)
    plane = face.plane
    n = Geom::Vector3d.new(plane[0], plane[1], plane[2])
    d = plane[3]
    k = scale_vector(n, -d)
    world_transformation = get_world_transformation(face)
    n2 = world_transformation * n
    k2 = world_transformation * k
    d2 = -n2.dot(k2)
    return [n2.x, n2.y, n2.z, d2]
  end

  def combind_parent_transformations(parents)
    transformation = IDENTITY
    for parent in parents do
      transformation = parent.transformation * transformation
    end
    return transformation
  end

  def get_world_transformation(entity)
    if entity.is_a?(Sketchup::Group)
      parent_transformation = get_world_transform(entity.parent)
      transformation = entity.transformation
      return parent_transformation * transformation
    elsif entity.is_a?(Sketchup::Model)
      return IDENTITY
    else
      return get_world_transformation(entity.parent);
    end
  end

  def scale_vector(v, a)
    return Geom::Vector3d::new(v.x * a, v.y * a, v.z * a)
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
