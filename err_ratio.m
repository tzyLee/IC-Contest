function ratio = err_ratio(real, act)
    ratio = err_dist(real, act)./abs(real);
end