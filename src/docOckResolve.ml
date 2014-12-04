(*
 * Copyright (c) 2014 Leo White <lpw25@cl.cam.ac.uk>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

open DocOckPaths
open DocOckTypes
open DocOckComponents
open DocOckComponentTbl

type 'a parent_module_path =
  | Resolved of 'a Path.Resolved.module_ * 'a Sig.t
  | Unresolved of 'a Path.module_

type 'a parent_module_type_path =
  | Resolved of 'a Path.Resolved.module_type * 'a Sig.t
  | Unresolved of 'a Path.module_type

let rec resolve_parent_module_path tbl p : 'a parent_module_path =
  let open Path.Resolved in
  let open Path in
    match p with
    | Root s -> begin
        match root tbl s with
        | None -> Unresolved p
        | Some r ->
            let p = Identifier (Identifier.Root r) in
              Resolved(p, resolved_module_path tbl p)
      end
    | Resolved r -> Resolved(r, resolved_module_path tbl r)
    | Dot(pr, name) -> begin
        match resolve_parent_module_path tbl pr with
        | Unresolved pr -> Unresolved(Dot(pr, name))
        | Resolved(pr, parent) ->
            let rec loop pr parent : 'a parent_module_path =
              try
                let Parent.Module md =
                  Sig.find_parent_module name parent
                in
                  Resolved(Module(pr, name), md)
              with Not_found ->
                try
                  match Sig.find_parent_subst parent with
                  | Parent.Subst subp -> begin
                      match resolve_parent_module_type_path tbl subp with
                      | Unresolved _ -> Unresolved(Dot(Resolved pr, name))
                      | Resolved(subpr, parent) ->
                          loop (Subst(subpr, pr)) parent
                    end
                  | Parent.SubstAlias subp -> begin
                      match resolve_parent_module_path tbl subp with
                      | Unresolved _ -> Unresolved(Dot(Resolved pr, name))
                      | Resolved(subpr, parent) ->
                          loop (SubstAlias(subpr, pr)) parent
                    end
                with Not_found -> Unresolved(Dot(Resolved pr, name))
            in
              loop pr parent
      end
    | Apply(pr, arg) -> begin
        let arg = resolve_module_path tbl arg in
        match resolve_parent_module_path tbl pr with
        | Unresolved pr -> Unresolved(Apply(pr, arg))
        | Resolved(pr, parent) ->
            let rec loop pr parent : 'a parent_module_path =
              try
                let Parent.Module md =
                  Sig.find_parent_apply (module_path tbl) arg parent
                in
                  Resolved(Apply(pr, arg), md)
              with Not_found ->
                try
                  match Sig.find_parent_subst parent with
                  | Parent.Subst subp -> begin
                      match resolve_parent_module_type_path tbl subp with
                      | Unresolved _ -> Unresolved(Apply(Resolved pr, arg))
                      | Resolved(subpr, parent) ->
                          loop (Subst(subpr, pr)) parent
                    end
                  | Parent.SubstAlias subp -> begin
                      match resolve_parent_module_path tbl subp with
                      | Unresolved _ -> Unresolved(Apply(Resolved pr, arg))
                      | Resolved(subpr, parent) ->
                          loop (SubstAlias(subpr, pr)) parent
                    end
                with Not_found -> Unresolved(Apply(Resolved pr, arg))
            in
              loop pr parent
      end

and resolve_parent_module_type_path tbl p : 'a parent_module_type_path =
  let open Path.Resolved in
  let open Path in
    match p with
    | Resolved r -> Resolved(r, resolved_module_type_path tbl r)
    | Dot(pr, name) -> begin
        match resolve_parent_module_path tbl pr with
        | Unresolved pr -> Unresolved(Dot(pr, name))
        | Resolved(pr, parent) ->
            let rec loop pr parent : 'a parent_module_type_path =
              try
                let Parent.ModuleType md =
                  Sig.find_parent_module_type name parent
                in
                  Resolved(ModuleType(pr, name), md)
              with Not_found ->
                try
                  match Sig.find_parent_subst parent with
                  | Parent.Subst subp -> begin
                      match resolve_parent_module_type_path tbl subp with
                      | Unresolved _ -> Unresolved(Dot(Resolved pr, name))
                      | Resolved(subpr, parent) ->
                          loop (Subst(subpr, pr)) parent
                    end
                  | Parent.SubstAlias subp -> begin
                      match resolve_parent_module_path tbl subp with
                      | Unresolved _ -> Unresolved(Dot(Resolved pr, name))
                      | Resolved(subpr, parent) ->
                          loop (SubstAlias(subpr, pr)) parent
                    end
                with Not_found -> Unresolved(Dot(Resolved pr, name))
            in
              loop pr parent
      end

and resolve_module_path tbl =
  let open Path.Resolved in
  let open Path in function
  | Root s as p -> begin
      match root tbl s with
      | None -> p
      | Some r -> Resolved (Identifier (Identifier.Root r))
    end
  | Resolved r as p -> p
  | Dot(p, name) -> begin
      match resolve_parent_module_path tbl p with
      | Unresolved p -> Dot(p, name)
      | Resolved(p, parent) ->
          try
            let Element.Module =
              Sig.find_module_element name parent
            in
              Resolved (Module(p, name))
          with Not_found -> Dot(Resolved p, name)
    end
  | Apply(p, arg) -> begin
      let arg = resolve_module_path tbl arg in
        match resolve_parent_module_path tbl p with
        | Unresolved p -> Apply(p, arg)
        | Resolved(p, parent) ->
            try
              let Element.Module =
                Sig.find_apply_element parent
              in
                Resolved (Apply(p, arg))
            with Not_found -> Apply(Resolved p, arg)
    end

and resolve_module_type_path tbl =
  let open Path.Resolved in
  let open Path in function
  | (Resolved r : 'a Path.module_type) as p -> p
  | Dot(p, name) -> begin
      match resolve_parent_module_path tbl p with
      | Unresolved p -> Dot(p, name)
      | Resolved(p, parent) ->
          try
            let Element.ModuleType =
              Sig.find_module_type_element name parent
            in
              Resolved (ModuleType(p, name))
          with Not_found -> Dot(Resolved p, name)
    end

and resolve_type_path tbl =
  let open Path.Resolved in
  let open Path in function
  | (Resolved r : 'a Path.type_) as p -> p
  | Dot(p, name) -> begin
      match resolve_parent_module_path tbl p with
      | Unresolved p -> Dot(p, name)
      | Resolved(p, parent) ->
          try
            let elem = Sig.find_type_element name parent in
              match elem with
              | Element.Type -> Resolved (Type(p, name))
              | Element.Class -> Resolved (Class(p, name))
              | Element.ClassType -> Resolved (ClassType(p, name))
          with Not_found -> Dot(Resolved p, name)
    end

and resolve_class_type_path tbl =
  let open Path.Resolved in
  let open Path in function
  | (Resolved r : 'a Path.class_type) as p -> p
  | Dot(p, name) -> begin
      match resolve_parent_module_path tbl p with
      | Unresolved p -> Dot(p, name)
      | Resolved(p, parent) ->
          try
            let elem = Sig.find_class_type_element name parent in
              match elem with
              | Element.Class -> Resolved (Class(p, name))
              | Element.ClassType -> Resolved (ClassType(p, name))
          with Not_found -> Dot(Resolved p, name)
    end

type 'a parent_fragment =
  | Resolved of 'a Fragment.Resolved.signature * 'a Sig.t
  | Unresolved of 'a Fragment.signature

let rec resolve_parent_fragment tbl base p
        : 'a parent_fragment =
  let open Fragment.Resolved in
  let open Fragment in
    match p with
    | (Resolved r : 'a signature) ->
          Resolved(r, resolved_signature_fragment tbl base r)
    | Dot(pr, name) -> begin
        match resolve_parent_fragment tbl base pr with
        | Unresolved pr -> Unresolved(Dot(pr, name))
        | Resolved(pr, parent) ->
            let rec loop pr parent : 'a parent_fragment =
              try
                let Parent.Module md =
                  Sig.find_parent_module name parent
                in
                  Resolved(Module(pr, name), md)
              with Not_found ->
                try
                  match Sig.find_parent_subst parent with
                  | Parent.Subst subp -> begin
                      match resolve_parent_module_type_path tbl subp with
                      | Unresolved _ -> Unresolved(Dot(Resolved pr, name))
                      | Resolved(subpr, parent) ->
                          loop (Subst(subpr, pr)) parent
                    end
                  | Parent.SubstAlias subp -> begin
                      match resolve_parent_module_path tbl subp with
                      | Unresolved _ -> Unresolved(Dot(Resolved pr, name))
                      | Resolved(subpr, parent) ->
                          loop (SubstAlias(subpr, pr)) parent
                    end
                with Not_found -> Unresolved(Dot(Resolved pr, name))
            in
              loop pr parent
      end

and resolve_module_fragment tbl base =
  let open Fragment.Resolved in
  let open Fragment in function
  | Resolved r as p -> p
  | Dot(p, name) -> begin
      match resolve_parent_fragment tbl base p with
      | Unresolved p -> Dot(p, name)
      | Resolved(p, parent) ->
          try
            let Element.Module =
              Sig.find_module_element name parent
            in
              Resolved (Module(p, name))
          with Not_found -> Dot(Resolved p, name)
    end

and resolve_type_fragment tbl base =
  let open Fragment.Resolved in
  let open Fragment in function
  | (Resolved r : 'a Fragment.type_) as p -> p
  | Dot(p, name) -> begin
      match resolve_parent_fragment tbl base p with
      | Unresolved p -> Dot(p, name)
      | Resolved(p, parent) ->
          try
            let elem = Sig.find_type_element name parent in
              match elem with
              | Element.Type -> Resolved (Type(p, name))
              | Element.Class -> Resolved (Class(p, name))
              | Element.ClassType -> Resolved (ClassType(p, name))
          with Not_found -> Dot(Resolved p, name)
    end

type ('a, 'b) parent_reference =
  | ResolvedSig : 'a Reference.Resolved.signature * 'a Sig.t ->
                  ('a, [> `Module | `ModuleType]) parent_reference
  | ResolvedDatatype : 'a Reference.Resolved.datatype * 'a Datatype.t ->
                   ('a, [> `Type]) parent_reference
  | ResolvedClassSig : 'a Reference.Resolved.class_signature * 'a ClassSig.t ->
                   ('a, [> `Class | `ClassType]) parent_reference
  | Unresolved of 'a Reference.parent

type 'a parent_kind =
  | PParent : Kind.parent parent_kind
  | PSig : Kind.signature parent_kind
  | PDatatype : Kind.datatype parent_kind
  | PClassSig : Kind.class_signature parent_kind
  | PSigOrType : [Kind.signature | Kind.datatype] parent_kind

let find_parent_reference (type k) (kind : k parent_kind) r name parent
    : (_, k) parent_reference =
  let open Reference.Resolved in
    match kind with
    | PParent -> begin
        match Sig.find_parent name parent with
        | Parent.Module md -> ResolvedSig(Module(r, name), md)
        | Parent.ModuleType md -> ResolvedSig(ModuleType(r, name), md)
        | Parent.Datatype t -> ResolvedDatatype(Type(r, name), t)
        | Parent.Class cls -> ResolvedClassSig(Class(r, name), cls)
        | Parent.ClassType cls -> ResolvedClassSig(ClassType(r, name), cls)
      end
    | PSig -> begin
        match Sig.find_parent_signature name parent with
        | Parent.Module md -> ResolvedSig(Module(r, name), md)
        | Parent.ModuleType md -> ResolvedSig(ModuleType(r, name), md)
      end
    | PDatatype -> begin
        match Sig.find_parent_datatype name parent with
        | Parent.Datatype t -> ResolvedDatatype(Type(r, name), t)
      end
    | PClassSig -> begin
        match Sig.find_parent_class_signature name parent with
        | Parent.Class cls -> ResolvedClassSig(Class(r, name), cls)
        | Parent.ClassType cls -> ResolvedClassSig(ClassType(r, name), cls)
      end
    | PSigOrType -> begin
        match Sig.find_parent_sig_or_type name parent with
        | Parent.Module md -> ResolvedSig(Module(r, name), md)
        | Parent.ModuleType md -> ResolvedSig(ModuleType(r, name), md)
        | Parent.Datatype t -> ResolvedDatatype(Type(r, name), t)
      end

let rec resolve_parent_reference :
  type k . k parent_kind -> 'a t ->
       'a Reference.parent -> ('a, k) parent_reference =
    fun kind tbl r ->
      let open Identifier in
      let open Reference.Resolved in
      let open Reference in
        match r with
        | Root s -> begin
            match root tbl s with
            | None -> Unresolved r
            | Some root ->
                let root = Identifier (Identifier.Root root) in
                  match kind with
                  | PParent ->
                      ResolvedSig(root, resolved_signature_reference tbl root)
                  | PSig ->
                      ResolvedSig(root, resolved_signature_reference tbl root)
                  | PSigOrType ->
                      ResolvedSig(root, resolved_signature_reference tbl root)
                  | _ -> Unresolved r
          end
        | Resolved
            (Identifier (Root _ | Module _ | Argument _ | ModuleType _)
             | Module _ | ModuleType _ as rr) -> begin
            match kind with
            | PParent ->
                ResolvedSig(rr, resolved_signature_reference tbl rr)
            | PSig ->
                ResolvedSig(rr, resolved_signature_reference tbl rr)
            | PSigOrType ->
                ResolvedSig(rr, resolved_signature_reference tbl rr)
            | _ -> Unresolved r
          end
        | Resolved
            (Identifier (Class _ | ClassType _)
            | Class _ | ClassType _ as rr) -> begin
            match kind with
            | PParent ->
                ResolvedClassSig(rr, resolved_class_signature_reference tbl rr)
            | PClassSig ->
                ResolvedClassSig(rr, resolved_class_signature_reference tbl rr)
            | _ -> Unresolved r
          end
        | Resolved (Identifier (Type _ | CoreType _) | Type _ as rr) -> begin
            match kind with
            | PParent ->
                ResolvedDatatype(rr, resolved_datatype_reference tbl rr)
            | PDatatype ->
                ResolvedDatatype(rr, resolved_datatype_reference tbl rr)
            | PSigOrType ->
                ResolvedDatatype(rr, resolved_datatype_reference tbl rr)
            | _ -> Unresolved r
          end
        | Dot(r, name) -> begin
            match resolve_parent_reference PSig tbl r with
            | Unresolved r -> Unresolved(Dot(r, name))
            | ResolvedSig(r, parent) ->
                try
                  find_parent_reference kind r name parent
                with Not_found ->
                  let r = Resolved.parent_of_signature r in
                    Unresolved(Dot(Resolved r, name))
          end

and resolve_module_reference tbl r =
  let open Reference.Resolved in
  let open Reference in
    match r with
    | Root s -> begin
        match root tbl s with
        | None -> r
        | Some r -> Resolved (Identifier (Identifier.Root r))
      end
    | Resolved _ -> r
    | Dot(r, name) -> begin
        match resolve_parent_reference PSig tbl r with
        | Unresolved r -> Dot(r, name)
        | ResolvedSig(r, parent) ->
            try
              let Element.Module =
                Sig.find_module_element name parent
              in
                Resolved (Module(r, name))
            with Not_found ->
              let r = Resolved.parent_of_signature r in
                Dot(Resolved r, name)
      end

and resolve_module_type_reference tbl r =
  let open Reference.Resolved in
  let open Reference in
    match r with
    | Root _ -> r
    | Resolved _ -> r
    | Dot(r, name) -> begin
        match resolve_parent_reference PSig tbl r with
        | Unresolved r -> Dot(r, name)
        | ResolvedSig(r, parent) ->
            try
              let Element.ModuleType =
                Sig.find_module_type_element name parent
              in
                Resolved (ModuleType(r, name))
            with Not_found ->
              let r = Resolved.parent_of_signature r in
                Dot(Resolved r, name)
      end

and resolve_type_reference tbl r =
  let open Reference.Resolved in
  let open Reference in
    match r with
    | Root _ -> r
    | Resolved _ -> r
    | Dot(r, name) -> begin
        match resolve_parent_reference PSig tbl r with
        | Unresolved r -> Dot(r, name)
        | ResolvedSig(r, parent) ->
            try
              match Sig.find_type_element name parent with
              | Element.Type -> Resolved (Type(r, name))
              | Element.Class -> Resolved (Class(r, name))
              | Element.ClassType -> Resolved (ClassType(r, name))
            with Not_found ->
              let r = Resolved.parent_of_signature r in
                Dot(Resolved r, name)
      end

and resolve_constructor_reference tbl r =
  let open Reference.Resolved in
  let open Reference in
    match r with
    | Root _ -> r
    | Resolved _ -> r
    | Dot(r, name) -> begin
        match resolve_parent_reference PSigOrType tbl r with
        | Unresolved r -> Dot(r, name)
        | ResolvedSig(r, parent) -> begin
            try
              match Sig.find_constructor_element name parent with
              | Element.Constructor type_name ->
                  Resolved (Constructor(Type(r, type_name), name))
              | Element.Extension -> Resolved (Extension(r, name))
              | Element.Exception -> Resolved (Exception(r, name))
            with Not_found ->
              let r = Resolved.parent_of_signature r in
                Dot(Resolved r, name)
          end
        | ResolvedDatatype(r, parent) -> begin
            try
              let Element.Constructor _ =
                Datatype.find_constructor_element name parent
              in
                Resolved (Constructor(r, name))
            with Not_found ->
              let r = Resolved.parent_of_datatype r in
                Dot(Resolved r, name)
          end
      end

and resolve_field_reference tbl r =
  let open Reference.Resolved in
  let open Reference in
    match r with
    | Root _ -> r
    | Resolved _ -> r
    | Dot(r, name) -> begin
        match resolve_parent_reference PSigOrType tbl r with
        | Unresolved r -> Dot(r, name)
        | ResolvedSig(r, parent) -> begin
            try
              let Element.Field type_name =
                Sig.find_field_element name parent
              in
                Resolved (Field(Type(r, type_name), name))
            with Not_found ->
              let r = Resolved.parent_of_signature r in
                Dot(Resolved r, name)
          end
        | ResolvedDatatype(r, parent) -> begin
            try
              let Element.Field _ =
                Datatype.find_field_element name parent
              in
                Resolved (Field(r, name))
            with Not_found ->
              let r = Resolved.parent_of_datatype r in
                Dot(Resolved r, name)
          end
      end

and resolve_extension_reference tbl r =
  let open Reference.Resolved in
  let open Reference in
    match r with
    | Root _ -> r
    | Resolved _ -> r
    | Dot(r, name) -> begin
        match resolve_parent_reference PSig tbl r with
        | Unresolved r -> Dot(r, name)
        | ResolvedSig(r, parent) ->
            try
              match Sig.find_extension_element name parent with
              | Element.Extension -> Resolved (Extension(r, name))
              | Element.Exception -> Resolved (Exception(r, name))
            with Not_found ->
              let r = Resolved.parent_of_signature r in
                Dot(Resolved r, name)
      end

and resolve_exception_reference tbl r =
  let open Reference.Resolved in
  let open Reference in
    match r with
    | Root _ -> r
    | Resolved _ -> r
    | Dot(r, name) -> begin
        match resolve_parent_reference PSig tbl r with
        | Unresolved r -> Dot(r, name)
        | ResolvedSig(r, parent) ->
            try
              let Element.Exception =
                Sig.find_exception_element name parent
              in
                Resolved (Exception(r, name))
            with Not_found ->
              let r = Resolved.parent_of_signature r in
                Dot(Resolved r, name)
      end

and resolve_value_reference tbl r =
  let open Reference.Resolved in
  let open Reference in
    match r with
    | Root _ -> r
    | Resolved _ -> r
    | Dot(r, name) -> begin
        match resolve_parent_reference PSig tbl r with
        | Unresolved r -> Dot(r, name)
        | ResolvedSig(r, parent) ->
            try
              let Element.Value =
                Sig.find_value_element name parent
              in
                Resolved (Value(r, name))
            with Not_found ->
              let r = Resolved.parent_of_signature r in
                Dot(Resolved r, name)
      end

and resolve_class_reference tbl r =
  let open Reference.Resolved in
  let open Reference in
    match r with
    | Root _ -> r
    | Resolved _ -> r
    | Dot(r, name) -> begin
        match resolve_parent_reference PSig tbl r with
        | Unresolved r -> Dot(r, name)
        | ResolvedSig(r, parent) ->
            try
              let Element.Class =
                Sig.find_class_element name parent
              in
                Resolved (Class(r, name))
            with Not_found ->
              let r = Resolved.parent_of_signature r in
                Dot(Resolved r, name)
      end

and resolve_class_type_reference tbl r =
  let open Reference.Resolved in
  let open Reference in
    match r with
    | Root _ -> r
    | Resolved _ -> r
    | Dot(r, name) -> begin
        match resolve_parent_reference PSig tbl r with
        | Unresolved r -> Dot(r, name)
        | ResolvedSig(r, parent) ->
            try
              match Sig.find_class_type_element name parent with
              | Element.ClassType -> Resolved (ClassType(r, name))
              | Element.Class -> Resolved (Class(r, name))
            with Not_found ->
              let r = Resolved.parent_of_signature r in
                Dot(Resolved r, name)
      end

and resolve_method_reference tbl r =
  let open Reference.Resolved in
  let open Reference in
    match r with
    | Root _ -> r
    | Resolved _ -> r
    | Dot(r, name) -> begin
        match resolve_parent_reference PClassSig tbl r with
        | Unresolved r -> Dot(r, name)
        | ResolvedClassSig(r, parent) ->
            try
              let Element.Method =
                ClassSig.find_method_element name parent
              in
                Resolved (Method(r, name))
            with Not_found ->
              let r = Resolved.parent_of_class_signature r in
                Dot(Resolved r, name)
      end

and resolve_instance_variable_reference tbl r =
  let open Reference.Resolved in
  let open Reference in
    match r with
    | Root _ -> r
    | Resolved _ -> r
    | Dot(r, name) -> begin
        match resolve_parent_reference PClassSig tbl r with
        | Unresolved r -> Dot(r, name)
        | ResolvedClassSig(r, parent) ->
            try
              let Element.InstanceVariable =
                ClassSig.find_instance_variable_element name parent
              in
                Resolved (InstanceVariable(r, name))
            with Not_found ->
              let r = Resolved.parent_of_class_signature r in
                Dot(Resolved r, name)
      end

and resolve_label_reference tbl r =
  let open Reference.Resolved in
  let open Reference in
    match r with
    | Root _ -> r
    | Resolved _ -> r
    | Dot(r, name) -> begin
        match resolve_parent_reference PParent tbl r with
        | Unresolved r -> Dot(r, name)
        | ResolvedSig(r, parent) -> begin
            try
              match Sig.find_label_element name parent with
              | Element.Label (Some type_name) ->
                  Resolved (Label(Type(r, type_name), name))
              | Element.Label None ->
                  Resolved (Label(Resolved.parent_of_signature r, name))
            with Not_found ->
              let r = Resolved.parent_of_signature r in
                Dot(Resolved r, name)
          end
        | ResolvedDatatype(r, parent) -> begin
            let r = Resolved.parent_of_datatype r in
              try
                let Element.Label _ =
                  Datatype.find_label_element name parent
                in
                  Resolved (Label(r, name))
              with Not_found ->
                  Dot(Resolved r, name)
          end
        | ResolvedClassSig(r, parent) -> begin
            let r = Resolved.parent_of_class_signature r in
              try
                let Element.Label _ =
                  ClassSig.find_label_element name parent
                in
                  Resolved (Label(r, name))
              with Not_found ->
                  Dot(Resolved r, name)
          end
      end

and resolve_element_reference tbl r =
  let open Reference.Resolved in
  let open Reference in
    match r with
    | Root _ -> r
    | Resolved _ -> r
    | Dot(r, name) -> begin
        match resolve_parent_reference PParent tbl r with
        | Unresolved r -> Dot(r, name)
        | ResolvedSig(r, parent) -> begin
            try
              match Sig.find_element name parent with
              | Element.Module -> Resolved (Module(r, name))
              | Element.ModuleType -> Resolved (ModuleType(r, name))
              | Element.Type -> Resolved (Type(r, name))
              | Element.Constructor type_name ->
                  Resolved (Constructor(Type(r, type_name) , name))
              | Element.Field type_name ->
                  Resolved (Field(Type(r, type_name) , name))
              | Element.Extension -> Resolved (Extension(r, name))
              | Element.Exception -> Resolved (Exception(r, name))
              | Element.Value -> Resolved (Value(r, name))
              | Element.Class -> Resolved (Class(r, name))
              | Element.ClassType -> Resolved (ClassType(r, name))
              | Element.Label (Some type_name) ->
                  Resolved (Label(Type(r, type_name), name))
              | Element.Label None ->
                  Resolved (Label(Resolved.parent_of_signature r, name))
            with Not_found ->
              let r = Resolved.parent_of_signature r in
                Dot(Resolved r, name)
          end
        | ResolvedDatatype(r, parent) -> begin
            try
              match Datatype.find_element name parent with
              | Element.Constructor _ -> Resolved (Constructor(r , name))
              | Element.Field _ -> Resolved (Field(r , name))
              | Element.Label _ ->
                  Resolved (Label(Resolved.parent_of_datatype r, name))
            with Not_found ->
              let r = Resolved.parent_of_datatype r in
                Dot(Resolved r, name)
          end
        | ResolvedClassSig(r, parent) -> begin
            try
              match ClassSig.find_element name parent with
              | Element.Method -> Resolved (Method(r, name))
              | Element.InstanceVariable -> Resolved (InstanceVariable(r, name))
              | Element.Label _ ->
                  Resolved (Label(Resolved.parent_of_class_signature r, name))
            with Not_found ->
              let r = Resolved.parent_of_class_signature r in
                Dot(Resolved r, name)
          end
      end

class ['a] resolver tbl = object
  inherit ['a] DocOckMaps.types as super
  method root x = x

  method identifier_module x = x
  method identifier_module_type x = x
  method identifier_type x = x
  method identifier_constructor x = x
  method identifier_field x = x
  method identifier_extension x = x
  method identifier_exception x = x
  method identifier_value x = x
  method identifier_class x = x
  method identifier_class_type x = x
  method identifier_method x = x
  method identifier_instance_variable x = x
  method identifier_label x = x

  method path_module x = resolve_module_path tbl x
  method path_module_type x = resolve_module_type_path tbl x
  method path_type x = resolve_type_path tbl x
  method path_class_type x = resolve_class_type_path tbl x

  method module_type_expr expr =
    let open ModuleType in
    let expr = super#module_type_expr expr in
      match expr with
      | With(body, substs) ->
          let base = module_type_expr tbl body in
          let substs =
            List.map
              (function
                | ModuleEq(frag, eq) ->
                    ModuleEq(resolve_module_fragment tbl base frag, eq)
                | TypeEq(frag, eq) ->
                    TypeEq(resolve_type_fragment tbl base frag, eq)
                | ModuleSubst(frag, p) ->
                    ModuleSubst(resolve_module_fragment tbl base frag, p)
                | TypeSubst(frag, params, p) ->
                    TypeSubst(resolve_type_fragment tbl base frag, params, p))
              substs
          in
            With(body, substs)
      | _ -> expr
  method fragment_type x = x
  method fragment_module x = x

  method reference_module x = resolve_module_reference tbl x
  method reference_module_type x = resolve_module_type_reference tbl x
  method reference_type x = resolve_type_reference tbl x
  method reference_constructor x = resolve_constructor_reference tbl x
  method reference_field x = resolve_field_reference tbl x
  method reference_extension x = resolve_extension_reference tbl x
  method reference_exception x = resolve_exception_reference tbl x
  method reference_value x = resolve_value_reference tbl x
  method reference_class x = resolve_class_reference tbl x
  method reference_class_type x = resolve_class_type_reference tbl x
  method reference_method x = resolve_method_reference tbl x
  method reference_instance_variable x = resolve_instance_variable_reference tbl x
  method reference_label x = resolve_label_reference tbl x
  method reference_any x = resolve_element_reference tbl x

end

let build_resolver lookup fetch =
  let tbl = create lookup fetch in
    new resolver tbl

let resolve r u = r#unit u