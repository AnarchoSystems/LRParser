//
//  Closure.swift
//
//
//  Created by Markus Kasperczyk on 29.10.23.
//

public protocol Node : Hashable {
    associatedtype Edge : Hashable
    var canReach : [Edge: [Self]] {get}
}

public struct ClosedGraph<N : Node> : Hashable {
    
    public let nodes : [N]
    public let edges : [N.Edge : [Int : [Int]]]
    
    public init(seeds: [N]) {
        
        // local variables so they're mutable
        var nodes = seeds
        var edges : [N.Edge : [N : Set<N>]] = [:]
        
        // we need these to keep track of nodes to expand
        var newNodes = seeds
        var seenNodes : Set<N> = Set(seeds)
        
        
        while true {
            
            // we need these to keep track if there are *next* nodes to expand or any edges that were added
            var newNewNodes : [N] = []
            var didAddEdge = false
            
            for start in newNodes {
                for (content, ends) in start.canReach {
                    for end in ends {
                        
                        if !seenNodes.contains(end) {
                            seenNodes.insert(end)
                            newNewNodes.append(end)
                        }
                        if edges[content] == nil {
                            edges[content] = [start : [end]]
                            didAddEdge = true
                        }
                        else if edges[content]![start] == nil {
                            edges[content]![start] = [end]
                            didAddEdge = true
                        }
                        else {
                            let (didAdd, _) = edges[content]![start]!.insert(end)
                            didAddEdge = didAddEdge || didAdd
                        }
                    }
                }
            }
            
            newNodes = newNewNodes
            if newNodes.isEmpty && !didAddEdge {
                break
            }
            nodes.append(contentsOf: newNodes)
        }
        
        self.nodes = nodes
        
        // every edge must now begin and end at a node in the nodes array
        self.edges = edges.mapValues{dict in
            Dictionary(uniqueKeysWithValues: dict.map{key, vals in (nodes.firstIndex(of: key)!,
                                                                    vals.map{nodes.firstIndex(of: $0)!})})
        }
    }
    
}
