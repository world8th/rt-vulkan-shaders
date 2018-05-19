int cdelta( in int a, in int b ){
#if defined(INTEL_PLATFORM)
    uvec2 acode = Mortoncodes[a], bcode = Mortoncodes[b];
    acode.x = a, bcode.x = b;
    return nlz(acode^bcode);
#else 
    uvec2 acode = Mortoncodes[a], bcode = Mortoncodes[b];
    int pfx = nlz(acode^bcode);
    return pfx + (pfx < 64 ? 0 : nlz(a^b));
#endif
}

int findSplit( in int first, in int last) {
    int commonPrefix = cdelta(first, last), split = first, nstep = last - first;
    IFALL (commonPrefix >= 64 || nstep <= 1) { split = (split + last)>>1; } else // if morton code equals
    { //fast search SAH split
        [[dependency_infinite, dependency_length(4)]]
        do {
            int newSplit = split + (nstep = (nstep + 1) >> 1), code = cdelta(split, newSplit);
            split = code > commonPrefix ? newSplit : split;
        } while (nstep > 1);
    }
    return clamp(split, first, last-1);
}

void splitNode(in int fID, in int side) {
    // select elements, include sibling
    int prID = fID + side;

    [[flatten]]
    if (prID >= 0 && fID >= 0) {
        // initial box and refit status
        bvhBoxesWork[prID] = vec4[2](100000.f.xxxx, -100000.f.xxxx); // initial AABB
        Flags[prID] = 0; // reset flag of refit

        // splitting nodes
        ivec4 _pdata = imageLoad(bvhMeta, prID)-1;

        [[flatten]]
        if (_pdata.x >= 0 && _pdata.y >= 0) {

            [[flatten]]
            if (_pdata.y != _pdata.x) {

                // find split
                int split = findSplit(_pdata.x, _pdata.y);
                ivec4 transplit = ivec4(_pdata.x, split+0, split+1, _pdata.y);
                bvec2 isLeaf = lessThan(transplit.yw - transplit.xz, ivec2(1,1));
                
                // resolve branch
                int hd = lCounterInc();
                imageStore(bvhMeta, prID, ivec4(hd.xx+ivec2(0,1)+(1).xx, _pdata.zw+1));
                imageStore(bvhMeta, hd+0, ivec4(transplit.xy, prID, -1)+1);
                imageStore(bvhMeta, hd+1, ivec4(transplit.zw, prID, -1)+1);

                // add prefix to next task
                Actives[aCounterInc()][cBuffer] = hd+1;
            } 

            // if leaf, add to leaf list
            [[flatten]]
            if (_pdata.y == _pdata.x) {
                LeafIndices[cCounterInc()] = prID+1;
            }
        }
    }
}