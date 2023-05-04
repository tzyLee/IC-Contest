function dist = err_dist(real, act)
    dist = ((real - act) .* (real - act)) .^ 0.5;
end
